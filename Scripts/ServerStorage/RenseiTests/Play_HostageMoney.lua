-- Play_HostageMoney (hostages plan Task 11, 2026-10-28; rulings R9-R11, pre-flight P12-P15, P23, P26): money between
-- saves -- the ransom (one server-side capped transfer: debit, then credit, refunded on failure) and the turn-in at a
-- State desk (the bounty only from a fine actually paid). Run in the game VM (LMRunSuite), every case inside
-- HostageKit.Guard (the hook's snapshot armed AND DataManager.IsNoSave()), so the mock profile is the one charged. Every
-- case sets the player's mock Data.Money by hand first (pre-flight P14: never the owner's real balance) and puts it back
-- after (KeepMoney); the Heat cases put the player's Heat back after (KeepHeat). Stand-ins come from HostageKit (the
-- stand-in seam): each starts with $1,000 (HostageKit.StandIn's default) at level 20.
-- Written by hand (pre-flight P15; never read from Rensei.Hostage at check time): the tiers at level 20 are 50, 500, 1000
-- and 2000 (tier 2 = $500, net $450; tier 4 = $2,000, net $1,800: 10% goes missing); the cap is $5,000 and the floor
-- $50; the fine at level 20 is 100 x 20 = $2,000 and the bounty half of it, $1,000; Wanted 1 from Heat 20, Wanted 3
-- from Heat 100 (Rensei.Heat.Thresholds); the State desk's jurisdiction is "State" (Brask's PayFine, P12); the desk range
-- 12 studs.
-- * The transfer: no yield (one coroutine resume), all or nothing, refunded when the credit fails, the amount guarded.
-- * The demand (Menu "Ransom", the tier index range-checked: Task 8 review M7, menu half): every other party member of
--   the hostage present here is asked (a real player through DialogueService.Ask; a stand-in answers through
--   HostageService._Answer, the function the popup's answer calls); the first Pay frees the hostage ("ransomed"), once;
--   only an asked member can pay (P14); a release voids the demand; everyone refusing or RansomWait passing ends it, the
--   hold going on, the popups closed (P14); one demand per session ("Already asked", P14); a server audit line per
--   transfer (P14).
-- * The turn-in (Menu "TurnIn", ruling R7, P12, P13): offered only within the desk range of a desk
--   (HostageService.Desks: Brask in Ye; the Foundry has none, so a temp model carrying Brask's DialogueId on the kit floor
--   and HostageService._RefreshDesks, pre-flight P23 / ruling T1-2) with the hostage Wanted in the desk's jurisdiction;
--   the fine charged (Wanted 3+ too, P13), the Heat cleared, half the fine paid as the bounty; a broke fugitive: Heat
--   cleared, no bounty. The pair is bound AT the desk (pre-flight P6: moving a held pair into town is a "teleport"): the
--   player knocked 6 studs in front of the desk (as TestKit.Beside puts a character), the stand-in captor 3 studs
--   further out, facing it; SmokeKit.Guarded puts the player back after.
local SSS = game:GetService("ServerScriptService")
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local TK = require(script.Parent.TakedownKit)
local HK = require(script.Parent.HostageKit)
local Player = TK.Player()

local At, WaitFor = TK.At, TK.WaitFor
local TIERS_20 = {50, 500, 1000, 2000} -- written by hand: Rensei.Hostage.RansomTiers(20)
local J = "State" -- written by hand: the desk's jurisdiction (Brask's PayFine, pre-flight P12)

local function Svc()
	local M = SSS:FindFirstChild("HostageService")
	assert(M, "HostageService exists")
	return require(M)
end
local function Prog() return require(SSS.ProgressionService) end
local function HeatSvc() return require(SSS.HeatService) end
local function Dialogue() return require(SSS.DialogueService) end
local function Money() return Prog().GetData(Player).Money end
local function SetMoney(N)
	Prog().GetData(Player).Money = N
	Prog().Sync(Player)
end
local function Copy(X)
	if type(X) ~= "table" then return X end
	local O = {}
	for K, V in pairs(X) do O[K] = Copy(V) end
	return O
end
-- Body with the player's mock Data.Money put back after it, failed or not
local function KeepMoney(Body)
	local Was = Money()
	local Ok, Err = pcall(Body)
	pcall(SetMoney, Was)
	if not Ok then error(Err, 0) end
end
-- Body with the player's Heat (the mock save's Morality.Heat) put back after it, failed or not
local function KeepHeat(Body)
	local D = Prog().GetData(Player)
	D.Morality = D.Morality or {}
	local Was = Copy(D.Morality.Heat)
	local Ok, Err = pcall(Body)
	D.Morality.Heat = Was
	pcall(HeatSvc().Publish, Player, true)
	if not Ok then error(Err, 0) end
end
-- every case: Guard, the money kept, the player's money set by hand first
local function Case(Start, Body)
	HK.Guard(function() KeepMoney(function()
		SetMoney(Start)
		Body()
	end) end)
end
local function Ids(Options)
	local Out = {}
	for _, O in ipairs(Options or {}) do table.insert(Out, O.Id) end
	return Out
end
local function Option(Options, Id)
	for _, O in ipairs(Options or {}) do if O.Id == Id then return O end end
	return nil
end
-- a deed's lifetime count on the player's (mock) profile, 0 when never recorded
local function DeedCount(Id)
	local M = Prog().GetData(Player).Morality
	local E = M and M.Deeds and M.Deeds[Id]
	return E and E.Count or 0
end
-- Body with Module[Field] swapped for Fn, put back after, failed or not
local function Swap(Module, Field, Fn, Body)
	local Real = Module[Field]
	Module[Field] = Fn
	local Ok, Err = pcall(Body, Real)
	Module[Field] = Real
	if not Ok then error(Err, 0) end
end
local function Has(List, Text)
	for _, X in ipairs(List) do if X == Text then return true end end
	return false
end

-- a stand-in captor holding a stand-in hostage on the kit floor: the hostage knocked at the spot, the captor 3 studs off
-- (facing it), the bind; Held within 2 s, else an error. The player stands 10 studs off (a bystander, a payer).
local function StandInPair(HostOpts, CapOpts)
	local Hos, HosPL = HK.StandIn(At(0, 0), HostOpts)
	DM.Knock(Hos)
	local Cap, CapPL = HK.StandIn(At(0, 3), CapOpts)
	TK.PutPlayer(At(10, 0) + Vector3.new(0, 3, 0))
	local Ok, Why = Svc().Take(CapPL, Hos)
	Cap.HumanoidRootPart.Anchored = true
	assert(Ok, "StandInPair: the stand-in's take starts (" .. tostring(Why) .. ")")
	local Held = WaitFor(2.0, function()
		local S = Svc().SessionOf(CapPL)
		return S ~= nil and S.State == "Held"
	end)
	assert(Held, "StandInPair: Held within 2 s (" .. tostring(HK.Result(Cap)) .. ")")
	return Cap, CapPL, Hos, HosPL, Svc().SessionOf(CapPL)
end

-- the real player holding a stand-in whose party is Payers (stand-ins made first, 8+ studs off on the floor)
local function HeldWithPayers(N, Money)
	local Payers = {}
	for I = 1, N do
		local _, PL = HK.StandIn(At(8 + 4 * I, 0), {Money = Money})
		table.insert(Payers, PL)
	end
	local Rig, PL, S = HK.Held({Party = Payers})
	return Rig, PL, S, Payers
end

-- ===== the desk (ruling R7, pre-flight P23 / ruling T1-2) =====
-- the first desk HostageService finds, or (no desk in this place: the Foundry) a temp model carrying Brask's DialogueId
-- on the kit floor 20 studs -Z of the spot, facing +Z, the service's desks refreshed (_RefreshDesks). Body(Desk) runs;
-- the temp desk is removed after and the desks refreshed again, or a real desk's NPC reset to Unaware
-- (PerceptionService.Reset, as TakedownKit.Spawn resets its rigs).
local function WithDesk(Body)
	local HS = Svc()
	local Desk = HS.Desks()[1]
	local Temp = nil
	if not Desk then
		Temp = Instance.new("Model")
		Temp.Name = "HostageTempDesk"
		local P = Instance.new("Part")
		P.Name = "HumanoidRootPart"
		P.Size = Vector3.new(2, 2, 1)
		P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch, P.Transparency = true, false, false, false, 1
		local Pos = At(0, -20).Position + Vector3.new(0, 3, 0)
		P.CFrame = CFrame.lookAt(Pos, Pos + Vector3.new(0, 0, 1))
		P.Parent = Temp
		Temp.PrimaryPart = P
		Temp:SetAttribute("DialogueId", "foundry_brask")
		Temp.Parent = workspace
		HS._RefreshDesks()
		Desk = HS.Desks()[1]
		assert(Desk == Temp, "WithDesk: the temp desk is found (" .. tostring(Desk) .. ")")
	end
	local Ok, Err = pcall(Body, Desk)
	-- the hold ended here, at the desk, and HostageService's hand-back of the player's root to its client (OWNER_BACK,
	-- 0.25 s after a release) waited out BEFORE the kit puts the player back: a put-back inside that window is undone
	-- when the client gets the root back with its stale spot (seen: the player left beside Brask after the suite)
	pcall(HS.Free, Player, "error")
	task.wait(0.5)
	-- a real desk's NPC (Brask, an Authority carrier) is put back to Unaware: with the kit holding PerceptionService's
	-- loop, it would otherwise go on perceiving the player, and a later suite's take on the kit floor would be witnessed
	if not Temp then pcall(require(SSS.PerceptionService).Reset, Desk) end
	if Temp then
		Temp:Destroy()
		pcall(HS._RefreshDesks)
	end
	if not Ok then error(Err, 0) end
end

-- the floor under Pos (a ray down, past characters and the desk), or Pos 3 studs down
local function FloorUnder(Pos, Skip)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local List = {Skip}
	for _, P in ipairs(game:GetService("Players"):GetPlayers()) do
		if P.Character then table.insert(List, P.Character) end
	end
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	if Live then table.insert(List, Live) end
	Params.FilterDescendantsInstances = List
	local R = workspace:Raycast(Pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), Params)
	return R and R.Position or (Pos - Vector3.new(0, 3, 0))
end

-- (pre-flight P6) the real player as the HOSTAGE, bound AT the desk: knocked Dist studs in front of the desk's root (the
-- way TestKit.Beside places a character), a stand-in captor 3 studs further out facing it, the bind; Held within 2 s.
local function CaptiveAtDesk(Desk, Dist)
	local DR = Desk:FindFirstChild("HumanoidRootPart") or Desk.PrimaryPart
	local Look = Vector3.new(DR.CFrame.LookVector.X, 0, DR.CFrame.LookVector.Z)
	Look = Look.Magnitude > 1e-3 and Look.Unit or Vector3.new(0, 0, -1)
	local PFloor = FloorUnder(DR.Position + Look * Dist, Desk)
	local CFloor = FloorUnder(DR.Position + Look * (Dist + 3), Desk)
	local Cap, CapPL = HK.StandIn(CFrame.lookAt(CFloor, CFloor - Look), {})
	TK.PutPlayer(CFrame.lookAt(PFloor + Vector3.new(0, 3, 0), PFloor + Vector3.new(0, 3, 0) - Look))
	assert(HK.KnockPlayer(), "CaptiveAtDesk: the player is knocked")
	local Ok, Why = Svc().Take(CapPL, Player.Character)
	Cap.HumanoidRootPart.Anchored = true
	assert(Ok, "CaptiveAtDesk: the stand-in's take starts (" .. tostring(Why) .. ")")
	local Held = WaitFor(2.0, function()
		local S = Svc().SessionOf(Player)
		return S ~= nil and S.State == "Held"
	end)
	assert(Held, "CaptiveAtDesk: Held within 2 s (" .. tostring(HK.Result(Cap)) .. ")")
	return Cap, CapPL, Svc().SessionOf(Player), (Cap.HumanoidRootPart.Position - DR.Position).Magnitude
end

-- the player's Heat in J set by hand: cleared, then Amount added (HeatService.Add on the mock profile)
local function SetHeat(Amount)
	HeatSvc().Clear(Player, J)
	if Amount > 0 then HeatSvc().Add(Player, J, Amount) end
end

return {
	-- ===== the transfer (R10) =====
	-- one coroutine resume runs it to the end: no yield anywhere in it
	TransferNoYield = function(T)
		Case(0, function()
			local _, Payer = HK.StandIn(At(8, 0))
			local Co = coroutine.create(function() return Svc().Transfer(Payer, Player, 500) end)
			local Resumed, Ok, Net = coroutine.resume(Co)
			T.Eq(Resumed, true, "the transfer ran without an error")
			T.Eq(coroutine.status(Co), "dead", "one resume ran it to the end: no yield")
			T.Eq(Ok, true, "the transfer went through")
			T.Eq(Net, 450, "the net: $500 less 10%")
			T.Eq(Money(), 450, "the player (the captor) +$450")
			T.Eq(Payer.Data.Money, 500, "the stand-in payer -$500 (from $1,000)")
		end)
	end,

	-- a payer who can't afford it: refused, and neither balance moves
	TransferAllOrNothing = function(T)
		Case(700, function()
			local _, Payer = HK.StandIn(At(8, 0), {Money = 100})
			local Ok, Why = Svc().Transfer(Payer, Player, 500)
			T.Eq(Ok, false, "refused")
			T.Eq(Why, "afford", "the reason")
			T.Eq(Payer.Data.Money, 100, "the payer's $100 untouched")
			T.Eq(Money(), 700, "the player's $700 untouched")
		end)
	end,

	-- the credit fails (the captor's _Grant stubbed false): the payer is refunded in the same step
	TransferRefundsOnFailedCredit = function(T)
		Case(1000, function()
			local HS = Svc()
			local _, Cap = HK.StandIn(At(8, 0))
			local Real = HS._Grant
			T.True(type(Real) == "function", "the money adapter _Grant exists")
			Swap(HS, "_Grant", function(PL, N)
				if PL == Cap then return false end
				return Real(PL, N)
			end, function()
				local Ok, Why = HS.Transfer(Player, Cap, 500) -- (the refund goes through the stub's real half)
				T.Eq(Ok, false, "refused")
				T.Eq(Why, "gone", "the reason")
				T.Eq(Money(), 1000, "the real payer refunded: $1,000")
				T.Eq(Cap.Data.Money, 1000, "the captor's money unchanged")
			end)
			T.Eq(HS._Grant, Real, "the real _Grant is back")
		end)
	end,

	-- only a whole number of dollars from $50 to $5,000
	TransferAmountGuards = function(T)
		Case(1000, function()
			local _, Payer = HK.StandIn(At(8, 0), {Money = 9000})
			for _, X in ipairs({49, 5001, 50.5, -1, "500", 0 / 0, math.huge}) do
				local Ok, Why = Svc().Transfer(Payer, Player, X)
				T.Eq(Ok, false, "amount " .. tostring(X) .. " refused")
				T.Eq(Why, "amount", "amount " .. tostring(X) .. ": the reason")
			end
			T.Eq(Payer.Data.Money, 9000, "the payer untouched")
			T.Eq(Money(), 1000, "the player untouched")
		end)
	end,

	-- ===== the demand (R9, P14) =====
	-- the real player as the payer: a stand-in captor holds a stand-in hostage whose party is {hostage, Player}; the demand
	-- of tier 4 ($2,000) opens a Dialogue popup for the player; their Pay moves the money and frees the hostage
	RansomPaidByParty = function(T)
		Case(3000, function()
			local HS = Svc()
			local Cap, CapPL, _, HosPL, S = StandInPair()
			HosPL.Party = {HosPL, Player}
			local Paid0 = DeedCount("paid_ransom")
			T.Eq(HS.Menu(CapPL, "Ransom", 4), true, "the demand is made")
			T.True(S.Demand ~= nil, "a live demand")
			T.Eq(S.Demand.Amount, 2000, "tier 4 at level 20: $2,000")
			T.Eq(Dialogue().IsOpen(Player), true, "the player has the popup open")
			HS._Answer(S, Player, 1)
			T.Eq(Money(), 1000, "the player paid $2,000 (from $3,000)")
			T.Eq(CapPL.Data.Money, 2800, "the captor +$1,800 (from $1,000)")
			T.Eq(S.Over, true, "the session ended")
			T.Eq(S.Outcome, "ransomed", "ransomed")
			T.Eq(HK.Result(Cap), "Bind:ransomed", "the captor's result")
			T.Eq(DeedCount("paid_ransom") - Paid0, 1, "paid_ransom +1 for the player")
			T.Eq(Dialogue().IsOpen(Player), false, "the popup is closed")
		end)
	end,

	-- the real player as the captor: tier 2 ($500) paid by the hostage's stand-in party member; +$450, took_ransom +1, one
	-- audit line naming the demand; Ransom was open with the level-20 tiers
	RansomCaptorGetsNet = function(T)
		Case(0, function() KeepHeat(function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(1)
			local O = Option(HS.MenuOptions(Player), "Ransom")
			T.Eq(O and O.Locked, false, "Ransom is open with a party member present")
			T.Same(O and O.Tiers, TIERS_20, "the tiers at level 20")
			local Took0 = DeedCount("took_ransom")
			local Logged = {}
			local Conn = game:GetService("LogService").MessageOut:Connect(function(Msg) table.insert(Logged, Msg) end)
			local Ok, Err = pcall(function()
				T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
				T.Eq(S.Demand.Amount, 500, "tier 2 at level 20: $500")
				local Id = S.Demand.Id
				HS._Answer(S, Payers[1], 1)
				T.Eq(Money(), 450, "the captor +$450")
				T.Eq(Payers[1].Data.Money, 500, "the payer -$500")
				T.Eq(S.Outcome, "ransomed", "ransomed")
				T.Eq(DeedCount("took_ransom") - Took0, 1, "took_ransom +1")
				task.wait(0.2)
				local Lines = 0
				for _, M in ipairs(Logged) do
					if M:find(Id, 1, true) and M:find("transfer", 1, true) then Lines += 1 end
				end
				T.Eq(Lines, 1, "one audit line naming the demand")
			end)
			Conn:Disconnect()
			if not Ok then error(Err, 0) end
		end) end)
	end,

	-- two Pays in the same frame: only the first is charged
	RansomPayOnce = function(T)
		Case(0, function() KeepHeat(function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(2)
			T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
			HS._Answer(S, Payers[1], 1)
			HS._Answer(S, Payers[2], 1)
			T.Eq(Payers[1].Data.Money, 500, "the first payer charged")
			T.Eq(Payers[2].Data.Money, 1000, "the second payer not charged")
			T.Eq(Money(), 450, "the captor paid once: +$450")
		end) end)
	end,

	-- a release voids the demand: a Pay after it charges nobody
	RansomVoidAfterRelease = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(1)
			T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
			HS.Free(Player, "released")
			T.Eq(S.Demand, nil, "the demand voided")
			HS._Answer(S, Payers[1], 1)
			T.Eq(Payers[1].Data.Money, 1000, "the payer not charged")
			T.Eq(Money(), 0, "the captor got nothing")
		end)
	end,

	-- everyone refuses: the demand ends, the captor is told, the hold goes on, nobody is charged
	RansomRefusedByAll = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(2)
			local Toasts = HK.Toasts(function()
				T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
				HS._Answer(S, Payers[1], 2)
				T.True(S.Demand ~= nil, "one refusal: the demand still stands")
				HS._Answer(S, Payers[2], 2)
			end)
			T.Eq(S.Demand, nil, "everyone refused: the demand ended")
			T.True(Has(Toasts, "Nobody will pay."), "the captor is told")
			T.Eq(S.Over, false, "the hold goes on")
			T.Eq(S.State, "Held", "still Held")
			T.Eq(Payers[1].Data.Money + Payers[2].Data.Money, 2000, "nobody charged")
			T.Eq(Money(), 0, "the captor got nothing")
		end)
	end,

	-- a hostage alone: Ransom locked "They have no party here", and the demand is refused
	RansomNoParty = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S = HK.Held()
			local O = Option(HS.MenuOptions(Player), "Ransom")
			T.Eq(O and O.Locked, true, "locked")
			T.Eq(O and O.Why, "They have no party here", "the reason")
			T.Eq(HS.Menu(Player, "Ransom", 1), false, "the demand is refused")
			T.Eq(S.Demand, nil, "no demand")
		end)
	end,

	-- RansomWait passed (Until set to now): the demand ends, the captor is told, the hold goes on, the popup closes
	RansomTimeout = function(T)
		Case(3000, function()
			local HS = Svc()
			local _, CapPL, _, HosPL, S = StandInPair()
			HosPL.Party = {Player}
			T.Eq(HS.Menu(CapPL, "Ransom", 2), true, "the demand is made")
			T.Eq(Dialogue().IsOpen(Player), true, "the player's popup is open")
			S.Demand.Until = os.clock()
			T.True(WaitFor(1.0, function() return S.Demand == nil end), "the demand ended")
			T.Eq(S.Over, false, "the hold goes on")
			T.Eq(S.State, "Held", "still Held")
			T.Eq(Dialogue().IsOpen(Player), false, "the unanswered popup is closed")
			T.Eq(Money(), 3000, "nobody charged")
			T.Eq(CapPL.Data.Money, 1000, "the captor got nothing")
		end)
	end,

	-- (P14) the captor is told "Nobody paid." at the timeout
	RansomTimeoutTellsCaptor = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S = HeldWithPayers(1)
			local Toasts = HK.Toasts(function()
				T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
				S.Demand.Until = os.clock()
				T.True(WaitFor(1.0, function() return S.Demand == nil end), "the demand ended")
			end)
			T.True(Has(Toasts, "Nobody paid."), "the captor is told")
			T.Eq(S.Over, false, "the hold goes on")
		end)
	end,

	-- (P14) only an asked member can pay: a stand-in outside the hostage's party charges nobody, and the demand stands
	RansomOnlyAsked = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(1)
			local _, Stranger = HK.StandIn(At(-8, 0))
			T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
			HS._Answer(S, Stranger, 1)
			T.Eq(Stranger.Data.Money, 1000, "the stranger not charged")
			T.Eq(Payers[1].Data.Money, 1000, "the party member not charged")
			T.Eq(Money(), 0, "the captor got nothing")
			T.True(S.Demand ~= nil and S.Demand.Paid == false, "the demand still stands, unpaid")
			T.Eq(S.Over, false, "the hold goes on")
		end)
	end,

	-- (P14) one demand per session: once one ended unpaid, Ransom is locked "Already asked" and a second is refused
	RansomOncePerSession = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S, Payers = HeldWithPayers(1)
			T.Eq(HS.Menu(Player, "Ransom", 2), true, "the demand is made")
			T.Eq(HS.Menu(Player, "Ransom", 2), false, "a second demand while one is live: refused")
			HS._Answer(S, Payers[1], 2)
			T.Eq(S.Demand, nil, "refused: the demand ended")
			local O = Option(HS.MenuOptions(Player), "Ransom")
			T.Eq(O and O.Locked, true, "locked")
			T.Eq(O and O.Why, "Already asked", "the reason")
			T.Eq(HS.Menu(Player, "Ransom", 2), false, "a second demand: refused")
			T.Eq(S.Demand, nil, "no new demand")
		end)
	end,

	-- (Task 8 review M7, menu half) the tier is an integer index inside the tiers, else refused
	RansomTierGuards = function(T)
		Case(0, function()
			local HS = Svc()
			local _, _, S = HeldWithPayers(1)
			for _, X in ipairs({0, 5, 2.5, -1, 0 / 0, math.huge, "2", false}) do
				T.Eq(HS.Menu(Player, "Ransom", X), false, "tier " .. tostring(X) .. " refused")
				T.Eq(S.Demand, nil, "tier " .. tostring(X) .. ": no demand")
			end
			T.Eq(HS.Menu(Player, "Ransom", nil), false, "no tier refused")
			T.Eq(S.Demand, nil, "no tier: no demand")
			T.Eq(HS.Menu(Player, "Ransom", 1), true, "control: tier 1 accepted")
			T.Eq(S.Demand and S.Demand.Amount, 50, "tier 1 is $50")
		end)
	end,

	-- ===== the turn-in (R7, P12, P13) =====
	-- Wanted 1 in the desk's jurisdiction, $5,000: the fine ($2,000) charged, the Heat cleared, the captor +$1,000, ended
	-- "turned_in", the hostage told
	TurnInPaysFine = function(T)
		Case(5000, function() KeepHeat(function() WithDesk(function(Desk)
			local HS = Svc()
			SetHeat(30)
			T.Eq(HeatSvc().Wanted(Player, J), 1, "setup: Wanted 1")
			local _, CapPL, S, Dist = CaptiveAtDesk(Desk, 6)
			T.True(Dist <= 12, "setup: the captor is within the desk range (" .. ("%.1f"):format(Dist) .. ")")
			T.True(table.find(Ids(HS.MenuOptions(CapPL)), "TurnIn") ~= nil, "TurnIn is offered")
			local Toasts = HK.Toasts(function()
				T.Eq(HS.Menu(CapPL, "TurnIn"), true, "turned in")
			end)
			T.Eq(Money(), 3000, "the fine charged: -$2,000")
			T.Eq(HeatSvc().Value(Player, J), 0, "the Heat cleared")
			T.Eq(CapPL.Data.Money, 2000, "the bounty: +$1,000 (from $1,000)")
			T.Eq(S.Outcome, "turned_in", "turned_in")
			T.True(#Toasts > 0, "the hostage is told")
		end) end) end)
	end,

	-- (pre-flight P13) Wanted 3 (past a desk fine): the fine still charged, the Heat cleared, the bounty paid
	TurnInWanted3Charges = function(T)
		Case(5000, function() KeepHeat(function() WithDesk(function(Desk)
			local HS = Svc()
			SetHeat(120)
			T.Eq(HeatSvc().Wanted(Player, J), 3, "setup: Wanted 3")
			local _, CapPL, S = CaptiveAtDesk(Desk, 6)
			T.True(table.find(Ids(HS.MenuOptions(CapPL)), "TurnIn") ~= nil, "TurnIn is offered")
			T.Eq(HS.Menu(CapPL, "TurnIn"), true, "turned in")
			T.Eq(Money(), 3000, "the fine charged: -$2,000")
			T.Eq(HeatSvc().Value(Player, J), 0, "the Heat cleared")
			T.Eq(CapPL.Data.Money, 2000, "the bounty: +$1,000")
			T.Eq(S.Outcome, "turned_in", "turned_in")
		end) end) end)
	end,

	-- a broke fugitive: the Heat cleared, nothing charged, no bounty (decision 8)
	TurnInClearsWhenBroke = function(T)
		Case(0, function() KeepHeat(function() WithDesk(function(Desk)
			local HS = Svc()
			SetHeat(30)
			local _, CapPL, S = CaptiveAtDesk(Desk, 6)
			T.Eq(HS.Menu(CapPL, "TurnIn"), true, "turned in")
			T.Eq(HeatSvc().Value(Player, J), 0, "the Heat cleared")
			T.Eq(Money(), 0, "the player's money still 0")
			T.Eq(CapPL.Data.Money, 1000, "no bounty")
			T.Eq(S.Outcome, "turned_in", "turned_in")
		end) end) end)
	end,

	-- Wanted 0: not offered, and the choice does nothing
	TurnInNotWanted = function(T)
		Case(5000, function() KeepHeat(function() WithDesk(function(Desk)
			local HS = Svc()
			SetHeat(0)
			local _, CapPL, S = CaptiveAtDesk(Desk, 6)
			T.Eq(table.find(Ids(HS.MenuOptions(CapPL)), "TurnIn"), nil, "TurnIn isn't offered")
			T.Eq(HS.Menu(CapPL, "TurnIn"), false, "the choice does nothing")
			T.Eq(S.Over, false, "the hold goes on")
			T.Eq(Money(), 5000, "nothing charged")
		end) end) end)
	end,

	-- 30 studs from the desk: not offered, and the choice does nothing
	TurnInFarFromDesk = function(T)
		Case(5000, function() KeepHeat(function() WithDesk(function(Desk)
			local HS = Svc()
			SetHeat(30)
			local _, CapPL, S, Dist = CaptiveAtDesk(Desk, 30)
			T.True(Dist > 12, "setup: the captor is beyond the desk range (" .. ("%.1f"):format(Dist) .. ")")
			T.Eq(table.find(Ids(HS.MenuOptions(CapPL)), "TurnIn"), nil, "TurnIn isn't offered")
			T.Eq(HS.Menu(CapPL, "TurnIn"), false, "the choice does nothing")
			T.Eq(S.Over, false, "the hold goes on")
			T.Eq(Money(), 5000, "nothing charged")
			T.Eq(HeatSvc().Wanted(Player, J), 1, "the Heat kept")
		end) end) end)
	end,
}

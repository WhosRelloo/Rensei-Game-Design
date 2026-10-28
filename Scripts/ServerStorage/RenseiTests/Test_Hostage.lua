-- Test_Hostage (hostages Task 2, 2026-10-27): Rensei.Hostage's numbers and pure rules, and the eight hostage deeds in
-- Rensei.Deeds. Every expected value is written by hand here, never read from the module (pre-flight P15). The module
-- is loaded inside each test, so with it missing every test fails on its own (RED) instead of the whole suite erroring
-- once.
local function Load()
	local M = game.ReplicatedStorage.Modules.Data.Rensei:FindFirstChild("Hostage")
	assert(M, "Rensei.Hostage is missing")
	return require(M)
end

local function Deeds() return require(game.ReplicatedStorage.Modules.Data.Rensei.Deeds) end

local Look = Vector3.new(0, 0, -1) -- the captor (or the target) faces -Z
local function FromFront(Deg, Dist) -- a point Deg degrees off straight in front of Look, Dist studs away
	local R = math.rad(Deg)
	return Vector3.new(math.sin(R), 0, -math.cos(R)) * (Dist or 3)
end

-- every gate passes: a grab from behind on a free, level-10 player
local function Good()
	return {
		IsNpc = false, IsPlayer = true, Self = false, Kind = "Grab", Safe = false, InDialogue = false,
		TargetLevel = 10, CaptorLevel = 10, Ready = true, Immune = false, CaptorFree = true, TargetFree = true,
		TargetKnocked = false, Dist = 3, Height = 0, Range = 4, Behind = true, Clear = true,
	}
end

return {
	-- a guard against an accidental edit: the owner changes these here and in the module together
	Numbers = function(T)
		local H = Load()
		T.Eq(H.Key, "N")
		T.Eq(H.BindTime, 1.5)
		T.Eq(H.GrabRange, 4)
		T.Eq(H.GrabStart, 0.4)
		T.Eq(H.GrabWindow, 3)
		T.Eq(H.LeadSpeed, 12)
		T.Eq(H.HoldTime, 180)
		T.Eq(H.RetakeWindow, 600)
		T.Eq(H.MinLevel, 5)
		T.Eq(H.MaxGap, 15)
		T.Eq(H.ImmuneAfter, 5)
		T.Eq(H.RansomCap, 5000)
		T.Eq(H.MissingShare, 0.10)
		T.Eq(H.BountyShare, 0.5)
		T.Eq(H.PairSlack, 1.5)
		T.Eq(H.TeleportBreak, 40)
		-- controller rulings: the station radius (T1-1, not the measured 285.7) and the struggle stat (P1 / T1-3)
		T.Eq(H.StationSafeRadius, 50, "station safe radius (PROPOSAL, ruling T1-1)")
		T.Eq(H.StruggleStat, "Strength", "the save has no Body stat")
		-- P26: the four numbers moved here from later tasks
		T.Eq(H.DeskRefresh, 30)
		T.Eq(H.StrugglePoseTime, 0.3)
		T.Eq(H.MaxPressesPerSend, 3)
		T.Eq(H.StunPad, 1)
	end,

	HoldTime = function(T)
		local H = Load()
		T.Eq(H.HoldTimeFor(0), 180, "first take")
		T.Eq(H.HoldTimeFor(1), 90, "one re-take")
		T.Eq(H.HoldTimeFor(2), 45)
		T.Eq(H.HoldTimeFor(3), 22.5)
		T.Eq(H.HoldTimeFor(4), 20, "the floor")
		T.Eq(H.HoldTimeFor(9), 20, "still the floor")
		T.Eq(H.HoldTimeFor(nil), 180, "no count: a first take")
		T.Eq(H.HoldTimeFor(-2), 180, "a negative count reads 0")
	end,

	Struggle = function(T)
		local H = Load()
		T.Near(H.StruggleGain(10, 10), 0.06, 1e-9, "even stats")
		T.Near(H.StruggleGain(30, 10), 0.12, 1e-9, "31/11 clamped to 2")
		T.Near(H.StruggleGain(0, 30), 0.03, 1e-9, "1/31 clamped to 0.5")
		T.Near(H.StruggleGain(nil, nil), 0.06, 1e-9, "missing stats read 0 on both sides")
	end,

	Lead = function(T)
		local H = Load()
		T.Near(H.LeadAllowance(0.1), 2.05, 1e-9, "one watch tick: (12 x 1.5 + 2.5) x 0.1")
		T.Near(H.LeadAllowance(1), 20.5, 1e-9, "one second")
		T.Near(H.LeadAllowance(5), 20.5, 1e-9, "a long gap counts as the 1 s window")
		T.Eq(H.LeadAllowance(-1), 0, "a negative gap allows nothing")
	end,

	Ransom = function(T)
		local H = Load()
		T.Same(H.RansomTiers(5), {50, 130, 250, 500}, "level 5 (125 rounds to 130)")
		T.Same(H.RansomTiers(60), {50, 1250, 2500, 5000}, "level 60: capped at 5000")
		T.Same(H.RansomTiers(1), {50, 100}, "level 1: a quarter and a half are below the minimum")
		T.Eq(H.Net(500), 450, "10% goes missing")
		T.Eq(H.Net(55), 49, "rounded down")
		T.Eq(H.Bounty(500), 250)
		T.Eq(H.Bounty(0), 0)
		T.Eq(H.Bounty(-5), 0, "never negative")
	end,

	-- the shield side: within 70 degrees of the captor's look. P10: the edge has the takedowns' 1e-3 degree tolerance
	InFront = function(T)
		local H = Load()
		T.Eq(H.InFront(Look, Vector3.new(0, 0, -3)), true, "straight ahead")
		T.Eq(H.InFront(Look, FromFront(70)), true, "70 degrees: the arc's edge")
		T.Eq(H.InFront(Look, FromFront(-70)), true, "70 degrees, the other side")
		T.Eq(H.InFront(Look, FromFront(71)), false, "71 degrees")
		T.Eq(H.InFront(Look, Vector3.new(3, 0, 0)), false, "the side")
		T.Eq(H.InFront(Look, Vector3.new(0, 0, 3)), false, "behind")
		T.Eq(H.InFront(Look, Vector3.zero), false, "zero offset")
		T.Eq(H.InFront(Vector3.zero, Vector3.new(0, 0, -3)), false, "zero look")
	end,

	BehindIsTakedowns = function(T)
		local H = Load()
		T.Eq(H.Behind(Look, Vector3.new(0, 0, 3)), true, "straight behind the target")
		T.Eq(H.Behind(Look, Vector3.new(0, 0, -3)), false, "in front of the target")
		local Takedown = require(game.ReplicatedStorage.Modules.Data.Rensei.Takedown)
		for _, Deg in ipairs({0, 60, 70, 71, 85, 120}) do
			local R = math.rad(Deg)
			local D = Vector3.new(math.sin(R), 0, math.cos(R)) * 3
			T.Eq(H.Behind(Look, D, 10), Takedown.Behind(Look, D, 10), Deg .. " degrees: the takedowns' answer")
		end
	end,

	CheckOrder = function(T)
		local H = Load()
		local Ok, Why = H.CheckTake(Good())
		T.Eq(Ok, true, "every gate passes (" .. tostring(Why) .. ")")
		T.Eq(Why, nil, "no reason when it passes")
		local Cases = {
			{"IsNpc", true, "not_player"},
			{"IsPlayer", false, "not_player"},
			{"Self", true, "self"},
			{"Kind", "Fly", "kind"},
			{"Safe", true, "safe"},
			{"InDialogue", true, "dialogue"},
			{"TargetLevel", 4, "level_low"},
			{"CaptorLevel", 25, "level_gap"}, -- TargetLevel 10 + 15
			{"Ready", false, "cooldown"},
			{"Immune", true, "immune"},
			{"CaptorFree", false, "busy"},
			{"TargetFree", false, "target_busy"},
			{"TargetKnocked", true, "kind"}, -- a knocked target is bound, never grabbed
			{"Dist", 4.01, "far"}, -- Range 4 + 0.01
			{"Height", 3.01, "far"},
			{"Behind", false, "seen"},
			{"Clear", false, "blocked"},
		}
		T.Eq(#Cases, 17, "17 gates")
		for _, Case in ipairs(Cases) do
			local C = Good()
			C[Case[1]] = Case[2]
			local O, W = H.CheckTake(C)
			T.Eq(O, false, Case[1] .. " broken: refused")
			T.Eq(W, Case[3], Case[1] .. " broken: reason")
		end
		-- edges that pass
		for Field, Value in pairs({Dist = 4, Height = -3, TargetLevel = 5}) do
			local C = Good()
			C[Field] = Value
			T.Eq(H.CheckTake(C), true, Field .. " = " .. tostring(Value) .. " still passes")
		end
		local C = Good()
		C.Dist, C.Range = 5.5, 5.5 -- the server's GrabRange + RangeSlack
		T.Eq(H.CheckTake(C), true, "the server's slack range")
	end,

	-- fails closed (the takedowns' lesson, Takedown FailClosed): a NaN distance or height, or no Range, is "far"
	FailClosed = function(T)
		local H = Load()
		local NaN = 0 / 0
		for _, Case in ipairs({{"Dist", NaN}, {"Height", NaN}, {"Dist", nil}, {"Height", nil}}) do
			local C = Good()
			C[Case[1]] = Case[2]
			local O, W = H.CheckTake(C)
			T.Eq(O, false, Case[1] .. " = " .. tostring(Case[2]) .. ": refused")
			T.Eq(W, "far", Case[1] .. " = " .. tostring(Case[2]) .. ": reason")
		end
		local C = Good()
		C.Range = nil
		T.Eq(H.CheckTake(C), true, "no Range: a grab uses 4 studs (3 passes)")
		C.Dist = 4.01
		T.Eq(select(2, H.CheckTake(C)), "far", "no Range: 4.01 is far for a grab")
		C.Kind, C.TargetKnocked, C.Dist = "Bind", true, 6
		T.Eq(H.CheckTake(C), true, "no Range: a bind uses 6 studs")
		C.Dist = 6.01
		T.Eq(select(2, H.CheckTake(C)), "far", "no Range: 6.01 is far for a bind")
		T.Eq(H.CheckTake(Good()), true, "control: the good context still passes")
	end,

	BindNeedsKnocked = function(T)
		local H = Load()
		local C = Good()
		C.Kind, C.TargetKnocked = "Bind", false
		local Ok, Why = H.CheckTake(C)
		T.Eq(Ok, false)
		T.Eq(Why, "kind", "a bind needs a knocked target")
		C.TargetKnocked, C.Behind = true, false
		T.Eq(H.CheckTake(C), true, "a bind doesn't need the rear arc")
	end,

	NpcFirst = function(T)
		local H = Load()
		local C = {
			IsNpc = true, IsPlayer = false, Self = true, Kind = "Fly", Safe = true, InDialogue = true,
			TargetLevel = 1, CaptorLevel = 99, Ready = false, Immune = true, CaptorFree = false, TargetFree = false,
			TargetKnocked = true, Dist = 99, Height = 99, Range = 4, Behind = false, Clear = false,
		}
		local Ok, Why = H.CheckTake(C)
		T.Eq(Ok, false)
		T.Eq(Why, "not_player", "the PvP rule is checked first")
		local Pass = Good()
		Pass.IsNpc = true
		T.Eq(select(2, H.CheckTake(Pass)), "not_player", "an NPC is refused even when everything else passes")
		Pass.IsPlayer = true -- an NPC that also claims to be a player
		T.Eq(select(2, H.CheckTake(Pass)), "not_player", "IsNpc wins over IsPlayer")
	end,

	LevelGapEdge = function(T)
		local H = Load()
		local C = Good()
		C.CaptorLevel, C.TargetLevel = 24, 10
		T.Eq(H.CheckTake(C), true, "14 levels apart")
		C.CaptorLevel = 25
		local Ok, Why = H.CheckTake(C)
		T.Eq(Ok, false)
		T.Eq(Why, "level_gap", "15 levels apart")
		C.CaptorLevel, C.TargetLevel = 10, 30
		T.Eq(H.CheckTake(C), true, "a higher target is no gap")
	end,

	Deeds = function(T)
		local D = Deeds()
		local Want = {
			took_hostage = {Conduct = {Mercy = -3, Order = -3}, Crime = 30},
			attempted_hostage = {Conduct = {Mercy = -1, Order = -1}, Crime = 15},
			released_hostage = {Conduct = {Mercy = 2}, Crime = nil},
			killed_hostage = {Conduct = {Mercy = -8, Order = -5}, Crime = 90},
			used_human_shield = {Conduct = {Mercy = -2}, Crime = 10},
			paid_ransom = {Conduct = {Mercy = 2}, Crime = nil},
			took_ransom = {Conduct = {Mercy = -3}, Crime = 20},
			turned_in_fugitive = {Conduct = {Order = 3}, Crime = nil},
		}
		local N = 0
		for Id, W in pairs(Want) do
			N += 1
			local E = D[Id]
			T.True(type(E) == "table", "Deeds." .. Id .. " exists")
			T.True(type(E.Text) == "string" and E.Text ~= "", Id .. " has a Text (its rumour line)")
			T.Same(E.Conduct, W.Conduct, Id .. " Conduct")
			T.Eq(E.Crime, W.Crime, Id .. " Crime")
			T.Eq(E.Scope, "Local", Id .. " Scope")
			T.Same(E.Repeat, {Cap = 5}, Id .. " Repeat")
		end
		T.Eq(N, 8, "eight deeds")
		T.Same(D.turned_in_fugitive.Standing, {Authority = 5}, "turned_in_fugitive Standing")
		T.Eq(D.took_hostage.Standing, nil, "took_hostage has no Standing")
	end,

	Anims = function(T)
		local H = Load()
		T.Same(H.Anims, {
			Bind = {Name = "Hostage_Bind", Fallback = "Takedown_Choke"}, -- Gripping's slot is empty (ruling T1-6)
			Hold = {Name = "Hostage_Hold", Fallback = "Carrying"},
			Held = {Name = "Hostage_Held", Fallback = "Takedown_ChokeVictim"},
			Struggle = {Name = "Hostage_Struggle", Fallback = "Takedown_ChokeVictim"},
		}, "the four slots and their fallbacks")
	end,
}

-- Rensei progression rules shared by server and client.
-- CONFIRMED: Mastery Points come in stages of 20. A player earns and spends all 20 of a stage,
-- then (with 0 unspent MP and enough EXP) undergoes the Truth/Gate trial; passing it opens the
-- next stage with 20 more MP. Everything else here is labelled PROPOSAL or UNRESOLVED.

local Progression = {}

Progression.MasteryPerStage = 20 -- CONFIRMED

-- CONFIRMED 2026-10-15 (skill tree spec): 5 stages = 100 MP lifetime, 4 Truth/Gate trials.
Progression.MaxStage = 5

-- PROPOSAL: lifetime EXP required to attempt the trial that ends stage N.
Progression.GateExp = {
	[1] = 6000,
	[2] = 20000,
	[3] = 50000,
}
Progression.GateExpGrowth = 2.2 -- PROPOSAL: stages past the table multiply the last entry

-- PROPOSAL: level curve. The alchemy sheet balances damage at L1 and L20.
Progression.MaxLevel = 20
-- CONFIRMED 2026-10-13: Stat Points (from levels) and Mastery Points (from training) are separate.
Progression.StatPointsPerLevel = 3 -- shown as "+3 Stat Points" in the UI mock; amount unconfirmed

function Progression.ExpToNext(Level)
	-- PROPOSAL: 300 at L1 rising to ~2,650 at L19 (about 22k EXP to cap)
	return math.floor(300 + 130 * (Level - 1) ^ 1.05)
end

function Progression.GateExpFor(Stage)
	local Fixed = Progression.GateExp[Stage]
	if Fixed then return Fixed end
	local Last = #Progression.GateExp
	return math.floor(Progression.GateExp[Last] * Progression.GateExpGrowth ^ (Stage - Last))
end

-- One shared verdict so the client never shows "ready" when the server would refuse.
-- Returns Eligible, {Reasons}
function Progression.GateCheck(Data)
	local Reasons = {}
	local Mastery = Data.Mastery
	local Gate = Data.Gate
	if not Mastery or not Gate then
		return false, {"Profile not loaded"}
	end
	if Gate.PendingTrial and Gate.PendingTrial > 0 then
		table.insert(Reasons, "A trial is already pending")
	end
	if Progression.MaxStage and Mastery.Stage >= Progression.MaxStage then
		table.insert(Reasons, "Final stage reached")
	end
	if Mastery.StageEarned < Progression.MasteryPerStage then
		table.insert(Reasons, ("Earn all %d Mastery Points of this stage (%d/%d)"):format(
			Progression.MasteryPerStage, Mastery.StageEarned, Progression.MasteryPerStage))
	end
	if Mastery.Unspent ~= 0 then
		table.insert(Reasons, ("Spend every Mastery Point (%d unspent)"):format(Mastery.Unspent))
	end
	local Need = Progression.GateExpFor(Mastery.Stage)
	if (Data.LifetimeExp or 0) < Need then
		table.insert(Reasons, ("Reach %d lifetime EXP (%d)"):format(Need, Data.LifetimeExp or 0))
	end
	return #Reasons == 0, Reasons
end

-- ===== Mastery training (PROPOSAL, see Rensei design report) =====
Progression.Training = {
	PointsPerMastery = 100, -- training progress (TP) per Mastery Point
	WindowSeconds = 3600, -- rolling window for per-source soft caps
	IdleSeconds = 90, -- no meaningful movement for this long = idle, earns nothing
	IdleDistance = 6,
	Sources = {
		-- Base TP per qualifying event, and the full-rate allowance per window.
		-- Beyond the allowance a source pays OverflowRate.
		CombatHit = {Base = 2, WindowAllowance = 300, OverflowRate = 0.15},
		Parry = {Base = 6, WindowAllowance = 150, OverflowRate = 0.15},
		Defeat = {Base = 25, WindowAllowance = 250, OverflowRate = 0.2},
		-- Alchemy trainers (TrainingService, 2026-10-16, PROPOSAL): a lesson is an exam-grade minigame
		-- (once a day each), an exercise a timed drill, an exam a one-time practical test. All still stop
		-- at the stage's 20 MP: only the Truth/Gate trial opens the next stage.
		Lesson = {Base = 40, WindowAllowance = 120, OverflowRate = 0.1},
		Exercise = {Base = 12, WindowAllowance = 72, OverflowRate = 0.1},
		Exam = {Base = 100, WindowAllowance = 200, OverflowRate = 0.25},
		Quest = {Base = 50, WindowAllowance = 300, OverflowRate = 0.5},
	},
	-- Repeatedly hitting the SAME opponent pays less (anti alt-farming).
	SameTarget = {FreeHits = 30, Rate = 0.2, ResetSeconds = 600},
}

return Progression

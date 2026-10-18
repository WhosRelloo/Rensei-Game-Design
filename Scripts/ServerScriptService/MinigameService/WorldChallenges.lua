-- WorldChallenges: MinigameService's WORLD kinds (2026-10-17). Same contract as the UI kinds (New -> Secret,
-- Public), plus:
--   World = true; Begin(Player, S) once the session opens; Tick(Player, S) every ~0.1s on the server ->
--   Outcome ("Pass" | "Fail" | nil), Text, Progress (pushed to the client's HUD tracker as "Reply");
--   End(Player, S) cleanup on any ending (pass, fail, cancel, leave, disconnect).
-- Everything is judged on the server from real game state; the client only ever shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local W = {}

local function Root(Player) return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

-- ===== Combat Read =====
-- A sparring partner (TuningConfig.Enemies.Sparring) attacks the player with the REAL combat pipeline
-- (AttackRunner, hitbox sweep, DamageManager: block / parry / dodge / i-frames). Each real attack is judged
-- from the result DamageManager gave it, so the drill teaches exactly the timings the game uses.
local function Plan(Def, Rng)
	local P, Real = {}, 0
	for I = 1, Def.Attacks do
		local Pick = Def.Pool[Rng:NextInteger(1, #Def.Pool)]
		P[I] = Pick
		Real += Pick == "String" and 2 or (Pick == "Feint" and 0 or 1)
	end
	if Real == 0 then P[1] = "Light" Real = 1 end
	return P, Real
end

local GOOD = {
	Light = {Blocked = true, Parried = true, PerfectParried = true, Dodged = true, IFramed = true},
	Heavy = {Blocked = true, Parried = true, PerfectParried = true, Dodged = true, IFramed = true},
	HeavyStrict = {Parried = true, PerfectParried = true, Dodged = true, IFramed = true},
	Unblockable = {Dodged = true, IFramed = true, Missed = true},
}

W.CombatRead = {World = true}
function W.CombatRead.New(Def, Rng)
	local P, Real = Plan(Def, Rng)
	local Need = math.min(Real, math.ceil(Real * Def.Need / Def.Attacks))
	return {Plan = P, Real = Real, Need = Need, Good = 0, Seen = 0, Rng = Rng},
		{Attacks = #P, Real = Real, Need = Need, Hint = Def.Hint}
end

function W.CombatRead.Begin(Player, S)
	local R = Root(Player)
	local EnemyService = require(ServerScriptService.EnemyService)
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local AttackRunner = require(ReplicatedStorage.Modules.Managers.AttackRunner)
	local Sec, Def = S.Secret, S.Def
	-- the partner appears 6 studs in front of the player, facing them
	local Look = Vector3.new(R.CFrame.LookVector.X, 0, R.CFrame.LookVector.Z).Unit
	local Spot = Instance.new("Part")
	Spot.Anchored, Spot.CanCollide, Spot.CanQuery, Spot.Transparency = true, false, false, 1
	Spot.CFrame = CFrame.lookAt(R.Position + Look * 6 - Vector3.new(0, 3, 0), R.Position - Vector3.new(0, 3, 0))
	Spot:SetAttribute("EnemyType", "Sparring")
	Spot:SetAttribute("Weapon", "")
	Spot.Parent = workspace
	local Ok, Foe = pcall(EnemyService.Spawn, Spot)
	Spot:Destroy() -- (Spawn only reads it; no respawn without it)
	if not Ok or not Foe then Sec.Outcome, Sec.Text = "Fail", "No room for a sparring partner here." return end
	Foe:SetAttribute("AIPassive", true) -- it only attacks when the drill says so
	Foe:SetAttribute("AdminGod", true) -- can't be hurt (nothing to farm)
	Foe:SetAttribute("DrillOwner", Player.UserId)
	Sec.Foe = Foe
	local FoeWC = WCS.Character.GetCharacterFromInstance(Foe)
	local Light1, Light2 = Tuning.Light.Hits[1], Tuning.Light.Hits[2]
	local Heavy = table.clone(Tuning.Heavy) Heavy.Telegraph = true
	local Unblock = table.clone(Tuning.Heavy) Unblock.Telegraph = true Unblock.Startup = Tuning.Heavy.Startup + 0.15

	local function Face()
		local FR, PR = Foe:FindFirstChild("HumanoidRootPart"), Root(Player)
		if FR and PR then
			local To = Vector3.new(PR.Position.X - FR.Position.X, 0, PR.Position.Z - FR.Position.Z)
			if To.Magnitude > 0.1 then FR.CFrame = CFrame.lookAt(FR.Position, FR.Position + To) end
		end
	end
	local function Attack(AttackDef, Name, Feint)
		Face()
		if Feint then
			task.delay(AttackDef.Startup * 0.55, function() if Foe.Parent then Foe:SetAttribute("FeintRequested", true) end end)
		end
		return AttackRunner.Run(FoeWC, AttackDef, Name, {Feintable = Feint == true, WalkSpeed = 0})
	end
	local function Judge(Kind, Results)
		local Got = "Missed"
		for _, X in ipairs(Results or {}) do
			if X.Victim == Player.Character then Got = X.Result or "IFramed" end
		end
		local Good = (GOOD[Kind] or {})[Got] == true
		Sec.Seen += 1
		if Good then Sec.Good += 1 end
		local Say = Good and "Read." or (Got == "Missed" and "Out of reach: hold your ground and read it."
			or (Got == "Blocked" and Kind == "HeavyStrict") and "Blocked a heavy: parry or dodge it at this level."
			or (Got == "Blocked" or Got == "GuardBroken") and Kind == "Unblockable" and "No guard stops that one: dodge."
			or "Hit.")
		Sec.Push = {Text = ("%s  ·  reads %d / %d needed  ·  %d of %d attacks"):format(Say, Sec.Good, Sec.Need, Sec.Seen, Sec.Real), Good = Good}
	end
	task.spawn(function()
		Sec.Push = {Text = "Ready. Combat Mode on (E). Watch the shoulders..."}
		task.wait(2.2)
		for _, P in ipairs(Sec.Plan) do
			if Sec.Closed or not Foe.Parent then return end
			if P == "Light" then
				local _, Res = Attack(Light1, "Light1") Judge("Light", Res)
			elseif P == "Heavy" then
				local _, Res = Attack(Heavy, "Heavy") Judge(Def.HeavyNeedsParry and "HeavyStrict" or "Heavy", Res)
			elseif P == "Feint" then
				Attack(Light1, "Light1", true) -- stops short: biting on it costs you the next read
				Sec.Push = {Text = ("Feint.  ·  reads %d / %d needed"):format(Sec.Good, Sec.Need)}
			elseif P == "String" then
				local _, R1 = Attack(Light1, "Light1") Judge("Light", R1)
				if Sec.Closed or not Foe.Parent then return end
				local _, R2 = Attack(Light2, "Light2") Judge("Light", R2)
			elseif P == "Unblockable" then
				local _, Res = Attack(Unblock, "DrillUnblockable") Judge("Unblockable", Res)
			end
			task.wait(Sec.Rng:NextNumber(Def.Gap[1], Def.Gap[2]))
		end
		if Sec.Closed then return end
		Sec.Outcome = Sec.Good >= Sec.Need and "Pass" or "Fail"
		Sec.Text = Sec.Outcome == "Pass" and nil or ("%d of %d reads (needed %d)."):format(Sec.Good, Sec.Real, Sec.Need)
	end)
end

function W.CombatRead.Tick(Player, S)
	local Sec = S.Secret
	local R = Root(Player)
	if Sec.Outcome then return Sec.Outcome, Sec.Text end
	if not R then return "Fail", "You went down." end
	if (R.Position - S.At).Magnitude > (S.Def.MaxDrift or 14) then return "Fail", "You walked away from the drill." end
	if Player.Character:GetAttribute("Knocked") then return "Fail", "Knocked down. Again, when you're up." end
	if Sec.Push then local P = Sec.Push Sec.Push = nil return nil, nil, P end
end

function W.CombatRead.End(Player, S)
	local Sec = S.Secret
	Sec.Closed = true
	local Foe = Sec.Foe
	if Foe and Foe.Parent then
		local H = Foe:FindFirstChildOfClass("Humanoid")
		if H then H.Health = 0 end
		task.delay(0.2, function() if Foe.Parent then Foe:Destroy() end end)
	end
end

-- tests / admin: the drill can't be "solved" by an answer; nothing to return
function W.CombatRead.Solve() return nil end

-- ===== Movement Gauntlet =====
-- A course = a Model tagged "RenseiGauntlet" with attribute GauntletId; its markers are parts named CP1, CP2...
-- (in order). A marker may carry Require ("LedgeWalk" | "Climb" | "WallRun": the player must be in that
-- traversal state -- the server's own MovementState -- when touching it), Label (the HUD objective) and
-- MinTier (only part of the route from that tier up). Reach every marker in order within the tier's time.
local function Course(Id)
	for _, M in ipairs(CollectionService:GetTagged("RenseiGauntlet")) do
		if M:GetAttribute("GauntletId") == Id then return M end
	end
end

W.MovementGauntlet = {World = true}
function W.MovementGauntlet.New(Def)
	local C = Course(Def.Course)
	local Points = {}
	if C then
		for _, P in ipairs(C:GetDescendants()) do
			local N = P:IsA("BasePart") and tonumber(P.Name:match("^CP(%d+)$"))
			if N and (P:GetAttribute("MinTier") or 1) <= (Def.Tier or 1) then table.insert(Points, {N = N, Part = P}) end
		end
		table.sort(Points, function(A, B) return A.N < B.N end)
	end
	local Labels = {}
	for I, P in ipairs(Points) do Labels[I] = P.Part:GetAttribute("Label") or ("Marker " .. I) end
	return {Points = Points, Index = 1}, {Total = #Points, TimeLimit = Def.TimeLimit, Labels = Labels, Hint = Def.Hint}
end

local function Objective(S)
	local Sec = S.Secret
	local P = Sec.Points[Sec.Index]
	local Left = math.max(0, S.Def.TimeLimit - (os.clock() - Sec.Started))
	return {Text = ("%d / %d  ·  %s  ·  %ds"):format(Sec.Index, #Sec.Points, P and (P.Part:GetAttribute("Label") or "Next marker") or "Done", math.ceil(Left))}
end

function W.MovementGauntlet.Begin(Player, S)
	local Sec = S.Secret
	if #Sec.Points == 0 then Sec.Outcome, Sec.Text = "Fail", "This course has no markers yet." return end
	Sec.Started = os.clock()
	Sec.NextPush = 0
end

local function Inside(Part, Pos)
	local L = Part.CFrame:PointToObjectSpace(Pos)
	local H = Part.Size / 2 + Vector3.new(1.5, 2.5, 1.5)
	return math.abs(L.X) <= H.X and math.abs(L.Y) <= H.Y and math.abs(L.Z) <= H.Z
end

function W.MovementGauntlet.Tick(Player, S)
	local Sec = S.Secret
	if Sec.Outcome then return Sec.Outcome, Sec.Text end
	local Character = Player.Character
	local R = Root(Player)
	if not R then return "Fail", "You went down." end
	if os.clock() - Sec.Started > S.Def.TimeLimit then return "Fail", ("Out of time (%d s). Again."):format(S.Def.TimeLimit) end
	if (R.Position - S.At).Magnitude > (S.Def.MaxDistance or 160) then return "Fail", "You left the course." end
	local P = Sec.Points[Sec.Index]
	if P and Inside(P.Part, R.Position) then
		local Need = P.Part:GetAttribute("Require")
		if not Need or Character:GetAttribute("Traversal") == Need then
			Sec.Index += 1
			if Sec.Index > #Sec.Points then
				return "Pass", ("Route done in %.1f s."):format(os.clock() - Sec.Started)
			end
			Sec.NextPush = 0
		elseif os.clock() >= (Sec.WarnAt or 0) then
			Sec.WarnAt = os.clock() + 2
			return nil, nil, {Text = ("This marker needs you %s."):format(({LedgeWalk = "on the ledge", Climb = "climbing", WallRun = "wall-running"})[Need] or Need)}
		end
	end
	if os.clock() >= Sec.NextPush then
		Sec.NextPush = os.clock() + 1
		return nil, nil, Objective(S)
	end
end

function W.MovementGauntlet.End() end
function W.MovementGauntlet.Solve() return nil end

return W

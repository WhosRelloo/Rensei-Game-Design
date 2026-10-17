-- AlchemyMinigames: the rules of the alchemy trainers' minigames (Rensei.Minigames entries with these
-- Kinds). SHARED: MinigameService (server) uses New + Check; MinigameUI's builders (client,
-- Modules.UI.AlchemyMinigameUI) use the same Simulate functions to preview each move, so what the player
-- sees is exactly what the server will compute. Nothing secret lives here: each puzzle's parameters are
-- dealt by the server (New) and the answer is re-simulated on the server (Check). Check returns
-- ok, reason -- the reason says WHAT went wrong, so a failure teaches something.
-- All numbers PROPOSALS.

local M = {}

local function Between(Rng, A, B) return Rng:NextInteger(A, B) end

-- ===================================================================================================
-- ReactionControl (Flame): bring a reaction chamber to ignition without letting it run away.
--   Each turn: HEAT Lower / Hold / Raise and the VENT Closed / Open. Then IGNITE.
--   Public = {T0, O0, Turns, Ign = {lo, hi}, Air = {lo, hi}, MaxT, MinO}
--   Answer = {Moves = {{H, V}, ...}}   H = -1 | 0 | 1, V = 0 | 1; ignition after the last move.
-- ===================================================================================================
local RC = {}
M.ReactionControl = RC

RC.Effects = {
	Heat = {[-1] = -10, [0] = 3, [1] = 14}, -- temperature change per turn (Hold: the reaction keeps creeping up)
	VentOpen = {T = -6, O = 18}, -- an open vent cools a little and feeds air
	VentClosed = {T = 0, O = -9}, -- a closed vent: the flame eats the air
}

-- Runs the moves. Returns {States = {{T, O}...}, Fail = reason | nil, FailTurn}
function RC.Simulate(P, Moves)
	local T, O = P.T0, P.O0
	local States = {{T = T, O = O}}
	for I, Move in ipairs(Moves) do
		local H, V = Move[1], Move[2]
		T += RC.Effects.Heat[H] + (V == 1 and RC.Effects.VentOpen.T or RC.Effects.VentClosed.T)
		O = math.clamp(O + (V == 1 and RC.Effects.VentOpen.O or RC.Effects.VentClosed.O), 0, 100)
		table.insert(States, {T = T, O = O})
		if T > P.MaxT then return {States = States, Fail = ("Turn %d: the heat passed %d. The reaction ran away from you - power isn't control."):format(I, P.MaxT), FailTurn = I} end
		if O < P.MinO then return {States = States, Fail = ("Turn %d: the air fell under %d and the flame choked."):format(I, P.MinO), FailTurn = I} end
	end
	return {States = States}
end

-- the verdict on igniting at the end of Moves
function RC.Verdict(P, Moves)
	if type(Moves) ~= "table" or #Moves == 0 then return false, "Take at least one turn first." end
	if #Moves > P.Turns then return false, ("Too many turns: the chamber allows %d."):format(P.Turns) end
	for _, Move in ipairs(Moves) do
		if type(Move) ~= "table" or not RC.Effects.Heat[Move[1]] or (Move[2] ~= 0 and Move[2] ~= 1) then return false, "Unreadable sequence." end
	end
	local R = RC.Simulate(P, Moves)
	if R.Fail then return false, R.Fail end
	local Last = R.States[#R.States]
	if Last.T < P.Ign[1] then return false, ("You ignited at %d: too cold. It needs %d-%d."):format(Last.T, P.Ign[1], P.Ign[2]) end
	if Last.T > P.Ign[2] then return false, ("You ignited at %d: too hot, it flashed over. It needs %d-%d."):format(Last.T, P.Ign[1], P.Ign[2]) end
	if Last.O < P.Air[1] then return false, ("Too little air (%d): it sputtered. It needs %d-%d."):format(Last.O, P.Air[1], P.Air[2]) end
	if Last.O > P.Air[2] then return false, ("Too much air (%d): it flared out of the chamber. It needs %d-%d."):format(Last.O, P.Air[1], P.Air[2]) end
	return true
end

-- every sequence of up to N turns (3 heat x 2 vent = 6 choices a turn): is the puzzle solvable?
-- Returns the first solution found (also used by MinigameService.Solve for tests).
local function Solvable(P)
	local Moves = {}
	local function Try(Depth)
		if Depth > 0 and RC.Verdict(P, Moves) then return true end
		if Depth >= P.Turns - 1 then return false end -- leave a turn of slack
		for H = -1, 1 do
			for V = 0, 1 do
				Moves[Depth + 1] = {H, V}
				local R = RC.Simulate(P, Moves)
				if not R.Fail and Try(Depth + 1) then return true end
				Moves[Depth + 1] = nil
			end
		end
		return false
	end
	if Try(0) then return Moves end
	return nil
end

function RC.Solve(Def, Secret) local Moves = Solvable(Secret.P) return Moves and {Moves = Moves} end

function RC.New(Def, Rng)
	for _ = 1, 60 do
		local IgnLo = Between(Rng, Def.IgnLo or 56, Def.IgnHi or 72)
		local AirLo = Between(Rng, 50, 64)
		local P = {
			T0 = Between(Rng, 20, 34), O0 = Between(Rng, 38, 58), Turns = Def.Turns or 7,
			Ign = {IgnLo, IgnLo + (Def.IgnWidth or 12)}, Air = {AirLo, AirLo + (Def.AirWidth or 16)},
			MinO = Def.MinO or 18,
		}
		P.MaxT = P.Ign[2] + (Def.Margin or 12)
		if Solvable(P) then return {P = P}, P end
	end
	-- (fallback: a known-solvable chamber)
	local P = {T0 = 28, O0 = 50, Turns = 7, Ign = {60, 72}, Air = {54, 70}, MinO = 18, MaxT = 84}
	return {P = P}, P
end

function RC.Check(Def, Secret, Answer)
	if type(Answer) ~= "table" then return false, "Unreadable sequence." end
	return RC.Verdict(Secret.P, Answer.Moves)
end

-- ===================================================================================================
-- PhaseSequence (Ice): freeze and thaw a row of pipes into the pattern the station needs.
--   Freeze N: pipe N turns to ice, and frost spreads to the next pipe DOWNSTREAM (N+1) if it holds water.
--   Thaw N: pipe N turns to water, and meltwater runs back UPSTREAM to thaw pipe N-1 if it's ice.
--   Three frozen pipes side by side expand too far and crack the casing.
--   Public = {N, Start = {bool...}, Target = {bool...}, MaxMoves}   (true = ice)
--   Answer = {Moves = {{Pipe, "F" | "T"}, ...}}
-- ===================================================================================================
local PS = {}
M.PhaseSequence = PS

function PS.Apply(N, State, Move)
	local S = table.clone(State)
	local I, Op = Move[1], Move[2]
	if Op == "F" then
		S[I] = true
		if I < N and not State[I + 1] then S[I + 1] = true end
	else
		S[I] = false
		if I > 1 and State[I - 1] then S[I - 1] = false end
	end
	return S
end

function PS.Cracked(N, S)
	for I = 1, N - 2 do
		if S[I] and S[I + 1] and S[I + 2] then return I end
	end
	return nil
end

-- Runs the moves: {States = {...}, Fail = reason | nil}
function PS.Simulate(P, Moves)
	local S = table.clone(P.Start)
	local States = {S}
	for K, Move in ipairs(Moves) do
		S = PS.Apply(P.N, S, Move)
		table.insert(States, S)
		local C = PS.Cracked(P.N, S)
		if C then
			return {States = States, Fail = ("Move %d: pipes %d to %d all froze together. Ice expands - the casing cracked."):format(K, C, C + 2)}
		end
	end
	return {States = States}
end

local function Same(A, B, N) for I = 1, N do if (A[I] or false) ~= (B[I] or false) then return false end end return true end

function PS.Verdict(P, Moves)
	if type(Moves) ~= "table" or #Moves == 0 then return false, "Make at least one move first." end
	if #Moves > P.MaxMoves then return false, ("Too many moves: the station allows %d."):format(P.MaxMoves) end
	for _, Move in ipairs(Moves) do
		if type(Move) ~= "table" or type(Move[1]) ~= "number" or Move[1] % 1 ~= 0 or Move[1] < 1 or Move[1] > P.N or (Move[2] ~= "F" and Move[2] ~= "T") then
			return false, "Unreadable sequence."
		end
	end
	local R = PS.Simulate(P, Moves)
	if R.Fail then return false, R.Fail end
	local Last = R.States[#R.States]
	if not Same(Last, P.Target, P.N) then
		local Wrong = {}
		for I = 1, P.N do if (Last[I] or false) ~= (P.Target[I] or false) then table.insert(Wrong, I) end end
		return false, ("Pipe%s %s %s the wrong phase. Watch where frost and meltwater spread."):format(#Wrong > 1 and "s" or "", table.concat(Wrong, ", "), #Wrong > 1 and "are" or "is")
	end
	return true
end

-- breadth-first over the 2^N states: the shortest legal sequence, or nil
local function PSSolve(P)
	local Key = function(S) local T = {} for I = 1, P.N do T[I] = S[I] and "1" or "0" end return table.concat(T) end
	local Seen = {[Key(P.Start)] = true}
	local Queue = {{S = P.Start, Moves = {}}}
	local Head = 1
	while Head <= #Queue do
		local Node = Queue[Head]
		Head += 1
		if Same(Node.S, P.Target, P.N) and #Node.Moves > 0 then return Node.Moves end
		if #Node.Moves < P.MaxMoves then
			for I = 1, P.N do
				for _, Op in ipairs({"F", "T"}) do
					local S = PS.Apply(P.N, Node.S, {I, Op})
					local K = Key(S)
					if not Seen[K] and not PS.Cracked(P.N, S) then
						Seen[K] = true
						local Moves = table.clone(Node.Moves)
						table.insert(Moves, {I, Op})
						table.insert(Queue, {S = S, Moves = Moves})
					end
				end
			end
		end
	end
	return nil
end

function PS.New(Def, Rng)
	local N = Def.Pipes or 6
	local function Random()
		for _ = 1, 50 do
			local S = {}
			for I = 1, N do S[I] = Rng:NextNumber() < 0.45 end
			if not PS.Cracked(N, S) then return S end
		end
		local S = {} for I = 1, N do S[I] = I % 2 == 0 end return S
	end
	for _ = 1, 80 do
		local P = {N = N, Start = Random(), Target = Random(), MaxMoves = Def.MaxMoves or 6}
		if not Same(P.Start, P.Target, N) then
			local Sol = PSSolve(P)
			if Sol and #Sol >= (Def.MinMoves or 3) and #Sol <= P.MaxMoves - (Def.Slack or 1) then return {P = P}, P end
		end
	end
	local P = {N = 6, Start = {true, false, false, true, false, false}, Target = {false, true, true, false, true, false}, MaxMoves = 6}
	return {P = P}, P
end

function PS.Check(Def, Secret, Answer)
	if type(Answer) ~= "table" then return false, "Unreadable sequence." end
	return PS.Verdict(Secret.P, Answer.Moves)
end

function PS.Solve(Def, Secret) local Moves = PSSolve(Secret.P) return Moves and {Moves = Moves} end

-- ===================================================================================================
-- LoadPaths (Earth): choose where the supports go under a loaded beam.
--   Every load goes to its NEAREST support (a tie splits it half and half). A support reaches loads
--   within Span columns; it can't stand on soft ground; it can carry Capacity at most. At most K supports.
--   Public = {N, Loads = {n...}, Soft = {bool...}, Span, Capacity, K}
--   Answer = {Supports = {column, ...}}
-- ===================================================================================================
local LP = {}
M.LoadPaths = LP

-- what each support carries, or the first problem: {Carried = {[col] = load}}, reason
function LP.Carry(P, Supports)
	local Carried = {}
	for _, S in ipairs(Supports) do Carried[S] = 0 end
	for I = 1, P.N do
		local L = P.Loads[I] or 0
		if L > 0 then
			local Best, Near = math.huge, {}
			for _, S in ipairs(Supports) do
				local D = math.abs(S - I)
				if D < Best then Best, Near = D, {S} elseif D == Best then table.insert(Near, S) end
			end
			if #Near == 0 or Best > P.Span then
				return {Carried = Carried}, ("The load over column %d has no support within %d columns: the beam sags there."):format(I, P.Span)
			end
			for _, S in ipairs(Near) do Carried[S] += L / #Near end
		end
	end
	return {Carried = Carried}
end

function LP.Verdict(P, Supports)
	if type(Supports) ~= "table" or #Supports == 0 then return false, "Place at least one support." end
	if #Supports > P.K then return false, ("Too many supports: you only have %d."):format(P.K) end
	local Seen = {}
	for _, S in ipairs(Supports) do
		if type(S) ~= "number" or S % 1 ~= 0 or S < 1 or S > P.N or Seen[S] then return false, "Unreadable placement." end
		Seen[S] = true
		if P.Soft[S] then return false, ("Column %d stands on soft ground: the support sank before it took any weight."):format(S) end
	end
	local R, Why = LP.Carry(P, Supports)
	if Why then return false, Why end
	for S, Load in pairs(R.Carried) do
		if Load > P.Capacity + 1e-6 then
			return false, ("The support at column %d carries %s; it holds %d. It cracked."):format(S, (Load % 1 == 0) and tostring(Load) or ("%.1f"):format(Load), P.Capacity)
		end
	end
	return true
end

local function LPSolve(P)
	local Best
	local Chosen = {}
	local function Try(From)
		if #Chosen > 0 and LP.Verdict(P, Chosen) then Best = table.clone(Chosen) return true end
		if #Chosen >= P.K then return false end
		for C = From, P.N do
			if not P.Soft[C] then
				table.insert(Chosen, C)
				if Try(C + 1) then return true end
				table.remove(Chosen)
			end
		end
		return false
	end
	Try(1)
	return Best
end

-- the smallest capacity any legal placement needs (to set a tight, still-solvable rating)
local function LPNeed(P)
	local Need = math.huge
	local Chosen = {}
	local function Try(From)
		if #Chosen > 0 then
			local R, Why = LP.Carry(P, Chosen)
			if not Why then
				local Max = 0
				for _, L in pairs(R.Carried) do Max = math.max(Max, L) end
				Need = math.min(Need, Max)
			end
		end
		if #Chosen >= P.K then return end
		for C = From, P.N do
			if not P.Soft[C] then
				table.insert(Chosen, C)
				Try(C + 1)
				table.remove(Chosen)
			end
		end
	end
	Try(1)
	return Need
end

function LP.New(Def, Rng)
	local N = Def.Columns or 7
	for _ = 1, 80 do
		local P = {N = N, Loads = {}, Soft = {}, Span = Def.Span or 2, K = Def.Supports or 3}
		-- Soft is a full array (false = rock): a remote turns sparse number keys into strings, and the
		-- client would read every column as rock
		for I = 1, N do P.Loads[I] = Rng:NextInteger(0, 4) P.Soft[I] = false end
		local SoftCount = Def.SoftCount or 2
		for _ = 1, SoftCount do P.Soft[Rng:NextInteger(1, N)] = true end
		local Need = LPNeed(P)
		if Need < math.huge and Need >= 3 then
			P.Capacity = math.ceil(Need) + (Def.Slack or 1)
			-- not too easy: the obvious "a support on every other column" must not just work
			if LPSolve(P) then return {P = P}, P end
		end
	end
	local P = {N = 7, Loads = {2, 3, 0, 4, 1, 3, 2}, Soft = {false, false, true, false, false, false, false}, Span = 2, K = 3, Capacity = 7}
	return {P = P}, P
end

function LP.Check(Def, Secret, Answer)
	if type(Answer) ~= "table" then return false, "Unreadable placement." end
	return LP.Verdict(Secret.P, Answer.Supports)
end

function LP.Solve(Def, Secret) return {Supports = LPSolve(Secret.P)} end

-- ===================================================================================================
-- PressureRouting (Wind): set the valves of a branching duct so every vent gets the pressure it needs.
--   The duct is a tree: valve 1 feeds valves 2 and 3, valve 2 feeds 4 and 5, ... (heap order); the last
--   row of valves feeds the vents. A valve sends everything LEFT, everything RIGHT, or SPLITS it in half.
--   Public = {Depth, Source, Targets = {pressure per vent}}
--   Answer = {Modes = {"L" | "R" | "S", ...}}  (one per valve)
-- ===================================================================================================
local PR = {}
M.PressureRouting = PR

function PR.Valves(Depth) return 2 ^ Depth - 1 end

-- the pressure reaching each valve and each vent
function PR.Flow(P, Modes)
	local NV = PR.Valves(P.Depth)
	local At = {[1] = P.Source}
	local Vents = {}
	for V = 1, NV do
		local In = At[V] or 0
		local Mode = Modes[V] or "S"
		local L = Mode == "L" and In or (Mode == "S" and In / 2 or 0)
		local R = Mode == "R" and In or (Mode == "S" and In / 2 or 0)
		local LC, RC2 = V * 2, V * 2 + 1
		if LC > NV then
			Vents[LC - NV] = (Vents[LC - NV] or 0) + L
			Vents[RC2 - NV] = (Vents[RC2 - NV] or 0) + R
		else
			At[LC] = L
			At[RC2] = R
		end
	end
	return {Valves = At, Vents = Vents}
end

function PR.Verdict(P, Modes)
	local NV = PR.Valves(P.Depth)
	if type(Modes) ~= "table" then return false, "Unreadable valve settings." end
	for V = 1, NV do
		if Modes[V] ~= "L" and Modes[V] ~= "R" and Modes[V] ~= "S" then return false, "Unreadable valve settings." end
	end
	local F = PR.Flow(P, Modes)
	for I = 1, NV + 1 do
		local Got, Need = F.Vents[I] or 0, P.Targets[I] or 0
		if math.abs(Got - Need) > 1e-6 then
			return false, ("Vent %d reads %s, it needs %s. Trace the line back: which valve feeds it?"):format(I, tostring(Got), tostring(Need))
		end
	end
	return true
end

function PR.New(Def, Rng)
	local Depth = Def.Depth or 2
	local NV = PR.Valves(Depth)
	local Source = Def.Source or (Depth == 2 and 8 or 16)
	for _ = 1, 50 do
		local Modes = {}
		for V = 1, NV do Modes[V] = ({"L", "R", "S"})[Rng:NextInteger(1, 3)] end
		local P = {Depth = Depth, Source = Source}
		local F = PR.Flow(P, Modes)
		P.Targets = {}
		local Zero, Busy = 0, 0
		for I = 1, NV + 1 do
			P.Targets[I] = F.Vents[I] or 0
			if P.Targets[I] == 0 then Zero += 1 else Busy += 1 end
		end
		-- something to think about: at least two vents fed and at least one dead
		if Busy >= 2 and Zero >= 1 then return {P = P, Modes = Modes}, P end
	end
	local P = {Depth = 2, Source = 8, Targets = {4, 0, 2, 2}}
	return {P = P, Modes = {"S", "L", "S"}}, P
end

function PR.Check(Def, Secret, Answer)
	if type(Answer) ~= "table" then return false, "Unreadable valve settings." end
	return PR.Verdict(Secret.P, Answer.Modes)
end

function PR.Solve(Def, Secret) return {Modes = Secret.Modes} end

-- ===================================================================================================
-- MaterialMatch (Metal): choose a material for every component of the machine. Each material is used once.
--   Public = {Materials = {{Name, Strength, Flex, Heat, Weight}...}, Parts = {{Name, Needs = {{Prop, Min | Max, Value}}}}}
--   Answer = {Pick = {[part index] = material index}}
-- ===================================================================================================
local MM = {}
M.MaterialMatch = MM

MM.Props = {"Strength", "Flex", "Heat", "Weight"}
MM.Pool = {
	{Name = "Cast Iron", Strength = 4, Flex = 1, Heat = 3, Weight = 5},
	{Name = "Tool Steel", Strength = 5, Flex = 2, Heat = 4, Weight = 4},
	{Name = "Spring Steel", Strength = 4, Flex = 5, Heat = 3, Weight = 3},
	{Name = "Copper", Strength = 2, Flex = 3, Heat = 2, Weight = 3},
	{Name = "Brass", Strength = 3, Flex = 2, Heat = 3, Weight = 3},
	{Name = "Bronze", Strength = 3, Flex = 2, Heat = 5, Weight = 3},
	{Name = "Tin", Strength = 1, Flex = 3, Heat = 1, Weight = 2},
	{Name = "Aluminium", Strength = 2, Flex = 3, Heat = 2, Weight = 1},
	{Name = "Lead", Strength = 1, Flex = 1, Heat = 2, Weight = 5},
}
MM.Components = {
	{Name = "Spring", Props = {{"Flex", "Min"}, {"Strength", "Min"}}},
	{Name = "Hinge Pin", Props = {{"Strength", "Min"}, {"Heat", "Min"}}},
	{Name = "Heat Shield", Props = {{"Heat", "Min"}, {"Weight", "Max"}}},
	{Name = "Gear", Props = {{"Strength", "Min"}, {"Weight", "Max"}}},
	{Name = "Bushing", Props = {{"Flex", "Min"}, {"Heat", "Min"}}},
	{Name = "Counterweight", Props = {{"Weight", "Min"}, {"Strength", "Max"}}},
}

local function Fits(Mat, Part)
	for _, N in ipairs(Part.Needs) do
		local V = Mat[N[1]]
		if N[2] == "Min" and V < N[3] then return false, ("%s %s is %d; the %s needs at least %d."):format(Mat.Name, N[1]:lower(), V, Part.Name, N[3]) end
		if N[2] == "Max" and V > N[3] then return false, ("%s %s is %d; the %s allows at most %d."):format(Mat.Name, N[1]:lower(), V, Part.Name, N[3]) end
	end
	return true
end
MM.Fits = Fits

function MM.Verdict(P, Pick)
	if type(Pick) ~= "table" then return false, "Choose a material for every part." end
	local Used = {}
	for I, Part in ipairs(P.Parts) do
		local M2 = Pick[I]
		if type(M2) ~= "number" or not P.Materials[M2] then return false, ("Choose a material for the %s."):format(Part.Name) end
		if Used[M2] then return false, ("You only have one piece of %s."):format(P.Materials[M2].Name) end
		Used[M2] = true
		local Ok, Why = Fits(P.Materials[M2], Part)
		if not Ok then return false, "The " .. Part.Name .. " failed: " .. Why end
	end
	return true
end

function MM.New(Def, Rng)
	local NParts = Def.Parts or 3
	local NMats = Def.Materials or 5
	for _ = 1, 100 do
		-- deal materials and components, then build requirements a hidden assignment meets (tightly)
		local Pool = table.clone(MM.Pool)
		Rng:Shuffle(Pool)
		local Mats = {}
		for I = 1, NMats do Mats[I] = table.clone(Pool[I]) end
		local Comps = table.clone(MM.Components)
		Rng:Shuffle(Comps)
		local Parts, Answer = {}, {}
		local Order = {}
		for I = 1, NMats do Order[I] = I end
		Rng:Shuffle(Order)
		for I = 1, NParts do
			local C = Comps[I]
			local Mat = Mats[Order[I]]
			local Needs = {}
			for _, Pr in ipairs(C.Props) do table.insert(Needs, {Pr[1], Pr[2], Mat[Pr[1]]}) end
			Parts[I] = {Name = C.Name, Needs = Needs}
			Answer[I] = Order[I]
		end
		local P = {Materials = Mats, Parts = Parts}
		-- worth thinking about: no part may accept every material
		local Easy = false
		for _, Part in ipairs(Parts) do
			local Fit = 0
			for _, Mat in ipairs(Mats) do if Fits(Mat, Part) then Fit += 1 end end
			if Fit >= NMats then Easy = true end
		end
		if not Easy and MM.Verdict(P, Answer) then return {P = P, Answer = Answer}, P end
	end
	local Mats = {table.clone(MM.Pool[3]), table.clone(MM.Pool[6]), table.clone(MM.Pool[8]), table.clone(MM.Pool[1]), table.clone(MM.Pool[7])}
	local P = {Materials = Mats, Parts = {
		{Name = "Spring", Needs = {{"Flex", "Min", 5}, {"Strength", "Min", 4}}},
		{Name = "Heat Shield", Needs = {{"Heat", "Min", 5}, {"Weight", "Max", 3}}},
		{Name = "Gear", Needs = {{"Strength", "Min", 2}, {"Weight", "Max", 1}}},
	}}
	return {P = P, Answer = {1, 2, 3}}, P
end

function MM.Check(Def, Secret, Answer)
	if type(Answer) ~= "table" then return false, "Choose a material for every part." end
	return MM.Verdict(Secret.P, Answer.Pick)
end

function MM.Solve(Def, Secret) return {Pick = Secret.Answer} end

return M

-- MinigameService: opens in-world minigames (Rensei.Minigames) and validates answers on the server.
-- Remotes.MinigameRemote: server -> client "Open" (Id, Params) / "Result" (Ok, Text);
-- client -> server "Submit" (Answer) / "Close" / "Act" (Arg: a step the server must answer, e.g. an
-- assay test; replied with "Reply" (Data)). The server keeps the seed (weights, scramble, sample,
-- cipher answer), so a client can't claim a pass it didn't earn. A pass: Story.Minigames[Id], quest
-- Signal "Minigame", the puzzle mechanism it was opened for (PuzzleService.OnMinigamePassed), and
-- on the FIRST pass only, Def.Evidence. A fail: try again (Kind.Failed resets what it used up).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Defs = require(ReplicatedStorage.Modules.Data.Rensei.Minigames)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local ProgressionService = require(ServerScriptService.ProgressionService)
local QuestService = require(ServerScriptService.QuestService)
local StoryService = require(ServerScriptService.StoryService)
local UIService = require(ServerScriptService.UIService)

local MAX_DRIFT = 22 -- studs a player may move from where the minigame opened

local MinigameService = {}

local Remote
local Sessions = {} -- [Player] = {Id, Def, Context, Secret, Public, At, Tries, LastSubmit, LastAct}

-- ===== generators: Secret stays on the server, Public goes to the client =====
local Kinds = {}

Kinds.PressureBoard = {
	New = function(Def, Rng)
		local N, Steps = Def.Valves, Def.Steps
		local Weights = {}
		local Bleed = Rng:NextInteger(1, N)
		for I = 1, N do
			local W = Rng:NextNumber(0.35, 1)
			Weights[I] = I == Bleed and -W * 0.8 or W
		end
		-- the target is the gauge at a random setting, so a solution always exists
		local Setting = {}
		for I = 1, N do Setting[I] = Rng:NextInteger(1, Steps - 1) end
		local Min, Max = 0, 0
		for I = 1, N do
			if Weights[I] > 0 then Max += Weights[I] * Steps else Min += Weights[I] * Steps end
		end
		local function Gauge(V)
			local Sum = 0
			for I = 1, N do Sum += Weights[I] * (V[I] or 0) end
			return (Sum - Min) / (Max - Min)
		end
		local Target = Gauge(Setting)
		local Start = {}
		for I = 1, N do Start[I] = 0 end
		-- the client draws the needle live from the weights (seeing the needle move IS the puzzle)
		return {Gauge = Gauge, Target = Target},
			{Valves = N, Steps = Steps, Weights = Weights, Min = Min, Max = Max, Target = Target, Band = Def.Band, Start = Start}
	end,
	Check = function(Def, Secret, Answer)
		if type(Answer) ~= "table" then return false end
		local V = {}
		for I = 1, Def.Valves do
			local X = tonumber(Answer[I])
			if not X or X ~= X or X % 1 ~= 0 or X < 0 or X > Def.Steps then return false end
			V[I] = X
		end
		return math.abs(Secret.Gauge(V) - Secret.Target) <= Def.Band / 2
	end,
}

Kinds.ArrayRestoration = {
	New = function(Def, Rng)
		local Offsets = {}
		local Any = false
		for I = 1, Def.Rings do
			Offsets[I] = Rng:NextInteger(0, Def.Positions - 1)
			if Offsets[I] ~= 0 then Any = true end
		end
		if not Any then Offsets[1] = 3 end
		return {Offsets = table.clone(Offsets)}, {Rings = Def.Rings, Positions = Def.Positions, Offsets = Offsets}
	end,
	-- Answer = moves {{Ring, Dir}, ...}; ring I turns, and drags ring I+1 the same way
	Check = function(Def, Secret, Answer)
		if type(Answer) ~= "table" or #Answer > 300 then return false end
		local O = table.clone(Secret.Offsets)
		local P = Def.Positions
		for _, Move in ipairs(Answer) do
			if type(Move) ~= "table" then return false end
			local Ring, Dir = tonumber(Move[1]), tonumber(Move[2])
			if not Ring or Ring % 1 ~= 0 or Ring < 1 or Ring > Def.Rings or (Dir ~= 1 and Dir ~= -1) then return false end
			O[Ring] = (O[Ring] + Dir) % P
			if Ring < Def.Rings then O[Ring + 1] = (O[Ring + 1] + Dir) % P end
		end
		for I = 1, Def.Rings do if O[I] ~= 0 then return false end end
		return true
	end,
}

local function RowOf(Def, Id)
	for _, Row in ipairs(Def.Table) do if Row.Id == Id then return Row end end
end

Kinds.AssayBench = {
	New = function(Def, Rng)
		local Sample = Def.Sample or Def.Table[Rng:NextInteger(1, #Def.Table)].Id
		-- the reference rows come in a fresh order each time; the reactions are only told per test
		local Order = {}
		for I = 1, #Def.Table do Order[I] = Def.Table[I].Id end
		Rng:Shuffle(Order)
		return {Sample = Sample, Left = Def.Chips, Used = {}}, {Tests = Def.Tests, Chips = Def.Chips, Order = Order}
	end,
	-- Arg = a test name; one chip each (a test already run is told again for free)
	Act = function(Def, Secret, Arg)
		if type(Arg) ~= "string" or not table.find(Def.Tests, Arg) then return nil end
		if Secret.Used[Arg] then return {Test = Arg, Result = Secret.Used[Arg], Left = Secret.Left} end
		if Secret.Left <= 0 then return {Test = Arg, Empty = true, Left = 0} end
		Secret.Left -= 1
		Secret.Used[Arg] = RowOf(Def, Secret.Sample)[Arg]
		return {Test = Arg, Result = Secret.Used[Arg], Left = Secret.Left}
	end,
	Failed = function(Def, Secret)
		Secret.Left = Def.Chips
		Secret.Used = {}
	end,
	Check = function(Def, Secret, Answer)
		return type(Answer) == "string" and Answer == Secret.Sample
	end,
}

local function Letters(Text)
	return string.upper((string.gsub(Text, "[^%a]", "")))
end

local function Encipher(Text, Key)
	return (string.gsub(string.upper(Text), "%u", function(C)
		return string.char((string.byte(C) - 65 + Key) % 26 + 65)
	end))
end

Kinds.LedgerCipher = {
	New = function(Def, Rng)
		local function Pick(List, Not)
			local V
			repeat V = List[Rng:NextInteger(1, #List)] until V ~= Not
			return V
		end
		local Marked = Rng:NextInteger(1, Def.Lines)
		local Place = Pick(Def.Places)
		local Lines = {}
		for I = 1, Def.Lines do
			local Cargo = I == Marked and Def.Marked or Pick(Def.Cargo)
			local To = I == Marked and Place or Pick(Def.Places, Place)
			Lines[I] = Encipher(Pick(Def.Counts) .. " CRATES " .. Cargo .. " TO " .. To, Def.Key)
		end
		-- the key is never sent: it's on a crate seal in the world
		return {Answer = Letters(Place)}, {Lines = Lines, Marked = Marked}
	end,
	Check = function(Def, Secret, Answer)
		return type(Answer) == "string" and #Answer <= 40 and Letters(Answer) == Secret.Answer
	end,
}

-- ===== open / submit =====
function MinigameService.Open(Player, Id, Context)
	local Def = Defs[Id]
	local Kind = Def and Kinds[Def.Kind]
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Kind or not Root or not Remote then return false end
	if Def.Requires then
		local Data = ProgressionService.GetData(Player)
		if not Data or not StoryLogic.Meets(Def.Requires, Data, Player) then
			UIService.Notify(Player, "Toast", {Text = Def.Locked or "You can't use this yet."})
			return false
		end
	end
	local Secret, Public = Kind.New(Def, Random.new())
	Sessions[Player] = {Id = Id, Def = Def, Kind = Kind, Context = Context, Secret = Secret,
		At = Root.Position, Tries = (Sessions[Player] and Sessions[Player].Id == Id and Sessions[Player].Tries) or 0}
	Remote:FireClient(Player, "Open", Id, Public)
	return true
end

local function Submit(Player, Answer)
	local S = Sessions[Player]
	if not S then return end
	local Now = os.clock()
	if S.LastSubmit and Now - S.LastSubmit < 0.3 then return end
	S.LastSubmit = Now
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Root or (Root.Position - S.At).Magnitude > MAX_DRIFT then
		Sessions[Player] = nil
		Remote:FireClient(Player, "Result", false, "You walked away from it.", true)
		return
	end
	local Ok = S.Kind.Check(S.Def, S.Secret, Answer)
	S.Tries += 1
	if not Ok then
		if S.Kind.Failed then S.Kind.Failed(S.Def, S.Secret) end
		Remote:FireClient(Player, "Result", false, S.Def.Fail)
		return
	end
	Sessions[Player] = nil
	local Data = ProgressionService.GetData(Player)
	local First = false
	if Data then
		local Rec = Data.Story.Minigames[S.Id] or {}
		First = Rec.Passed == nil
		Rec.Passed = Rec.Passed or os.time()
		Rec.Tries = (Rec.Tries or 0) + S.Tries
		Data.Story.Minigames[S.Id] = Rec
	end
	Remote:FireClient(Player, "Result", true, S.Def.Pass, true)
	UIService.Notify(Player, "Toast", {Text = S.Def.Pass})
	if First and S.Def.Evidence then StoryService.GiveEvidence(Player, S.Def.Evidence) end -- pays once
	QuestService.Signal(Player, "Minigame", S.Id)
	require(ServerScriptService.PuzzleService).OnMinigamePassed(Player, S.Context)
	ProgressionService.Sync(Player)
end

function MinigameService.Start()
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "MinigameRemote"
	Remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Remote.OnServerEvent:Connect(function(Player, Kind, Answer)
		if Kind == "Submit" then
			local Ok, Err = pcall(Submit, Player, Answer)
			if not Ok then warn("MinigameService submit failed:", Err) end
		elseif Kind == "Close" then
			Sessions[Player] = nil
		elseif Kind == "Act" then
			local S = Sessions[Player]
			local Now = os.clock()
			if not S or not S.Kind.Act or (S.LastAct and Now - S.LastAct < 0.15) then return end
			S.LastAct = Now
			local Ok, Reply = pcall(S.Kind.Act, S.Def, S.Secret, Answer)
			if not Ok then warn("MinigameService act failed:", Reply) return end
			if Reply then Remote:FireClient(Player, "Reply", Reply) end
		end
	end)
	Players.PlayerRemoving:Connect(function(Player) Sessions[Player] = nil end)
end

-- tests / admin: the server's own solution for the open session (never sent to clients)
function MinigameService.Solve(Player)
	local S = Sessions[Player]
	if not S then return nil end
	if S.Def.Kind == "ArrayRestoration" then
		local O, Moves = table.clone(S.Secret.Offsets), {}
		for I = 1, S.Def.Rings do
			while O[I] ~= 0 do
				table.insert(Moves, {I, -1})
				O[I] = (O[I] - 1) % S.Def.Positions
				if I < S.Def.Rings then O[I + 1] = (O[I + 1] - 1) % S.Def.Positions end
			end
		end
		return Moves
	elseif S.Def.Kind == "PressureBoard" then
		-- brute force (11^3 settings)
		local N, Steps = S.Def.Valves, S.Def.Steps
		local V = {}
		local function Try(I)
			if I > N then return S.Kind.Check(S.Def, S.Secret, V) end
			for X = 0, Steps do V[I] = X if Try(I + 1) then return true end end
			return false
		end
		return Try(1) and V or nil
	elseif S.Def.Kind == "AssayBench" then
		return S.Secret.Sample
	elseif S.Def.Kind == "LedgerCipher" then
		return S.Secret.Answer
	end
end

return MinigameService

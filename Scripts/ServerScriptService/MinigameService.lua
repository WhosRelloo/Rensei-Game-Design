-- MinigameService: opens in-world minigames (Rensei.Minigames) and validates answers on the server.
-- Remotes.MinigameRemote: server -> client "Open" (Id, Params) / "Result" (Ok, Text);
-- client -> server "Submit" (Answer) / "Close" / "Act" (Arg: a step the server must answer, e.g. an
-- assay test; replied with "Reply" (Data)). The server keeps the seed (weights, scramble, sample,
-- cipher answer), so a client can't claim a pass it didn't earn. A pass: Story.Minigames[Id], quest
-- Signal "Minigame", the puzzle mechanism it was opened for (PuzzleService.OnMinigamePassed), and
-- on the FIRST pass only, Def.Evidence. A fail: try again (Kind.Failed resets what it used up).
--
-- 2026-10-17 (challenge framework):
--   * DIFFICULTY TIERS: a definition with Track + Tiers gets the tier the player's matching stat earns
--     (TierFor: Combat -> best of Strength / Speed, Movement -> Speed, Alchemy -> Alchemy, Knowledge ->
--     Intelligence; 1-4 Initiate, 5-8 Apprentice, 9-12 Adept, 13-16 Expert, 17+ Master -- PROPOSAL). The
--     session plays a copy of the definition with Tiers[tier] laid over it; the client is told the tier.
--   * WORLD kinds (MinigameService.WorldChallenges: Combat Read, Movement Gauntlet): played in the world,
--     judged by the server's tick, shown on a HUD tracker.
--   * INTERRUPTIONS: every open session is watched -- dying, walking away (UI kinds), or being attacked
--     (unless AllowCombat) ends it cleanly.
--   * REWARD: Def.Reward = {Source, Mult, PerDay} pays Mastery training (ProgressionService.AddTraining) on a
--     pass, at most PerDay a day (counted in Story.Flags "Minigame_<Id>" through StoryService, only when it
--     paid), scaled by tier. The stage's 20 MP cap and the Truth/Gate still apply.
--   * PROMPTS: a part tagged "RenseiChallenge" with attribute MinigameId gets a "Begin" prompt.

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

-- While a minigame is open the character works at it (the sheet's "Build" animation, "can be used
-- for quests and minigames"); it stops on a pass, on closing, or on walking away.
local function Working(Player, On)
	local Character = Player.Character
	if not Character then return end
	local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
	if On then
		AnimationManager.Play(Character, "Misc_Build", {Looped = true, Priority = Enum.AnimationPriority.Action})
	else
		AnimationManager.Stop(Character, "Misc_Build")
	end
end

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

-- the alchemy trainers' kinds (ReactionControl, ...): shared rules, Check returns ok, reason
for Name, Kind in pairs(require(ReplicatedStorage.Modules.Data.Rensei.AlchemyMinigames)) do
	if type(Kind) == "table" and Kind.New and Kind.Check then Kinds[Name] = Kind end
end
-- the world challenges (Combat Read, Movement Gauntlet)
for Name, Kind in pairs(require(script.WorldChallenges)) do Kinds[Name] = Kind end

-- ===== difficulty tiers =====
MinigameService.TierNames = {"Initiate", "Apprentice", "Adept", "Expert", "Master"}
local TIER_MULT = {0.6, 0.8, 1, 1.2, 1.5} -- reward multiplier per tier (PROPOSAL)
local TRACK_STATS = {Combat = {"Strength", "Speed"}, Movement = {"Speed"}, Alchemy = {"Alchemy"}, Knowledge = {"Intelligence"}}
function MinigameService.TierFor(Data, Track)
	local Best = 1
	for _, Name in ipairs(TRACK_STATS[Track] or {}) do
		Best = math.max(Best, (Data and Data.Stats and Data.Stats[Name]) or 1)
	end
	return math.clamp(1 + math.floor((Best - 1) / 4), 1, 5)
end
local function ForTier(Def, Tier)
	if not Tier or not Def.Tiers then return Def end
	local Out = table.clone(Def)
	for K, V in pairs(Def.Tiers[Tier] or {}) do Out[K] = V end
	Out.Tier = Tier
	return Out
end

-- ===== open / submit =====
function MinigameService.Open(Player, Id, Context)
	local Def = Defs[Id]
	local Kind = Def and Kinds[Def.Kind]
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Kind or not Root or not Remote then return false end
	-- menus can't open in combat (UIState), so the client would drop the session unseen: say so here
	if Player.Character:GetAttribute("InCombat") and not Def.AllowCombat then
		UIService.Notify(Player, "Toast", {Text = "Not while you're fighting. Catch your breath first."})
		return false
	end
	if Def.Requires then
		local Data = ProgressionService.GetData(Player)
		if not Data or not StoryLogic.Meets(Def.Requires, Data, Player) then
			UIService.Notify(Player, "Toast", {Text = Def.Locked or "You can't use this yet."})
			return false
		end
	end
	if Sessions[Player] then MinigameService.Cancel(Player, nil) end -- one session at a time
	local Tier = nil
	if Def.Tiers then
		Tier = math.clamp(tonumber(type(Context) == "table" and Context.Tier) or MinigameService.TierFor(ProgressionService.GetData(Player), Def.Track), 1, #Def.Tiers)
	end
	local SessionDef = ForTier(Def, Tier)
	local Secret, Public = Kind.New(SessionDef, Random.new())
	Public = Public or {}
	Public.Tier, Public.TierName, Public.World = Tier, Tier and MinigameService.TierNames[Tier] or nil, Kind.World or nil
	local S = {Id = Id, Def = SessionDef, Kind = Kind, Context = Context, Secret = Secret, Tier = Tier,
		At = Root.Position, Tries = 0}
	Sessions[Player] = S
	Remote:FireClient(Player, "Open", Id, Public)
	if Kind.World then
		local Ok, Err = pcall(Kind.Begin, Player, S)
		if not Ok then warn("MinigameService world begin failed:", Err) MinigameService.Cancel(Player, "That challenge couldn't start.") return false end
	else
		Working(Player, true)
	end
	return true
end

-- End a session (any reason) and tell the client. Text = nil: silent.
function MinigameService.Cancel(Player, Text)
	local S = Sessions[Player]
	if not S then return end
	Sessions[Player] = nil
	if S.Kind.End then pcall(S.Kind.End, Player, S) end
	if not S.Kind.World then Working(Player, false) end
	if Text and Remote then Remote:FireClient(Player, "Result", false, Text, true) end
end

local function Today() return math.floor(os.time() / 86400) end
-- Mastery training for a pass, at most Reward.PerDay a day (counted only when it paid).
local function Reward(Player, S, Data)
	local R = S.Def.Reward
	if not R or not Data then return end
	local Key = "Minigame_" .. S.Id
	local V = Data.Story and Data.Story.Flags and Data.Story.Flags[Key]
	local Day, N = tostring(V or ""):match("^(%d+):(%d+)$")
	N = (tonumber(Day) == Today()) and tonumber(N) or 0
	if N >= (R.PerDay or 1) then
		UIService.Notify(Player, "Toast", {Text = "You've already trained this enough today."})
		return
	end
	local Paid = ProgressionService.AddTraining(Player, R.Source, (R.Mult or 1) * (TIER_MULT[S.Tier or 3] or 1), true)
	if Paid > 0 then
		StoryService.SetFlag(Player, Key, Today() .. ":" .. (N + 1), true)
	elseif Data.Mastery and Data.Mastery.StageEarned >= 20 then
		UIService.Notify(Player, "Toast", {Text = "You've learned all you can at this stage. Only the Gate opens the next."})
	end
end

local function Pass(Player, S, Text)
	Sessions[Player] = nil
	if S.Kind.End then pcall(S.Kind.End, Player, S) end
	if not S.Kind.World then Working(Player, false) end
	local Data = ProgressionService.GetData(Player)
	local First = false
	if Data then
		local Rec = Data.Story.Minigames[S.Id] or {}
		First = Rec.Passed == nil
		Rec.Passed = Rec.Passed or os.time()
		Rec.Tries = (Rec.Tries or 0) + S.Tries
		if S.Tier then Rec.BestTier = math.max(Rec.BestTier or 0, S.Tier) end
		Data.Story.Minigames[S.Id] = Rec
	end
	local Line = Text and (S.Def.Pass .. "  " .. Text) or S.Def.Pass
	Remote:FireClient(Player, "Result", true, Line, true)
	UIService.Notify(Player, "Toast", {Text = S.Def.Pass})
	if First and S.Def.Evidence then StoryService.GiveEvidence(Player, S.Def.Evidence) end -- pays once
	QuestService.Signal(Player, "Minigame", S.Id)
	require(ServerScriptService.PuzzleService).OnMinigamePassed(Player, S.Context)
	if type(S.Context) == "table" and S.Context.Lesson then
		require(ServerScriptService.TrainingService).OnLessonPassed(Player, S.Context.Lesson)
	end
	Reward(Player, S, Data)
	ProgressionService.Sync(Player)
end

local function Submit(Player, Answer)
	local S = Sessions[Player]
	if not S or S.Kind.World then return end -- world challenges are judged by the server's tick, not answers
	local Now = os.clock()
	if S.LastSubmit and Now - S.LastSubmit < 0.3 then return end
	S.LastSubmit = Now
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Root or (Root.Position - S.At).Magnitude > MAX_DRIFT then
		Sessions[Player] = nil
		Working(Player, false)
		Remote:FireClient(Player, "Result", false, "You walked away from it.", true)
		return
	end
	local Ok, Reason = S.Kind.Check(S.Def, S.Secret, Answer)
	S.Tries += 1
	if not Ok then
		if S.Kind.Failed then S.Kind.Failed(S.Def, S.Secret) end
		-- what went wrong (when the kind says), and after a few misses the definition's hint
		local Text = Reason or S.Def.Fail
		if S.Def.LateHint and S.Tries >= 3 then Text = Text .. "  Hint: " .. S.Def.LateHint end
		Remote:FireClient(Player, "Result", false, Text)
		return
	end
	Pass(Player, S)
end
MinigameService.Submit = Submit -- tests (Foundry Yard plan): the same path the remote takes

function MinigameService.Start()
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "MinigameRemote"
	Remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Remote.OnServerEvent:Connect(function(Player, Kind, Answer)
		if Kind == "Submit" then
			local Ok, Err = pcall(Submit, Player, Answer)
			if not Ok then warn("MinigameService submit failed:", Err) end
		elseif Kind == "Close" then
			MinigameService.Cancel(Player, Sessions[Player] and Sessions[Player].Kind.World and "You gave up the challenge." or nil)
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
	Players.PlayerRemoving:Connect(function(Player) MinigameService.Cancel(Player, nil) end)

	-- the watcher: world challenges tick; every session ends cleanly on death, walking away or an attack
	local Acc = 0
	game:GetService("RunService").Heartbeat:Connect(function(Dt)
		Acc += Dt
		if Acc < 0.1 then return end
		Acc = 0
		for Player, S in pairs(Sessions) do
			local Character = Player.Character
			local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			local Root = Character and Character:FindFirstChild("HumanoidRootPart")
			if not Humanoid or Humanoid.Health <= 0 or not Root then
				MinigameService.Cancel(Player, "You went down.")
			elseif Character:GetAttribute("InCombat") and not S.Def.AllowCombat then
				MinigameService.Cancel(Player, "Interrupted: you're under attack.")
			elseif not S.Kind.World and (Root.Position - S.At).Magnitude > MAX_DRIFT then
				MinigameService.Cancel(Player, "You walked away from it.")
			elseif S.Kind.World then
				local Ok, Outcome, Text, Progress = pcall(S.Kind.Tick, Player, S)
				if not Ok then
					warn("MinigameService world tick failed:", Outcome)
					MinigameService.Cancel(Player, "The challenge broke off.")
				elseif Outcome == "Pass" then
					Pass(Player, S, Text)
				elseif Outcome == "Fail" then
					S.Tries += 1
					MinigameService.Cancel(Player, Text or S.Def.Fail)
				elseif Progress and Remote then
					Remote:FireClient(Player, "Reply", Progress)
				end
			end
		end
	end)

	-- "Begin" prompts on parts tagged RenseiChallenge (attribute MinigameId)
	local CollectionService = game:GetService("CollectionService")
	local function Prompt(Part)
		local Id = Part:GetAttribute("MinigameId")
		local Def = Id and Defs[Id]
		if not Def or Part:FindFirstChild("ChallengePrompt") then return end
		local P = Instance.new("ProximityPrompt")
		P.Name = "ChallengePrompt"
		P.ActionText = "Begin"
		P.ObjectText = Def.Title
		P.HoldDuration = 0.3
		P.MaxActivationDistance = 10
		P.RequiresLineOfSight = false
		P.Triggered:Connect(function(Player) MinigameService.Open(Player, Id, {Prompt = Part}) end)
		P.Parent = Part
	end
	for _, Part in ipairs(CollectionService:GetTagged("RenseiChallenge")) do Prompt(Part) end
	CollectionService:GetInstanceAddedSignal("RenseiChallenge"):Connect(Prompt)
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
	elseif S.Kind.Solve then
		return S.Kind.Solve(S.Def, S.Secret)
	end
end

-- tests (Region Foundation Task 1): the id of the player's open minigame, or nil
function MinigameService.Current(Player)
	local S = Sessions[Player]
	return S and S.Id
end

return MinigameService

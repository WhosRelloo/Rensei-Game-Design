-- PuzzleService: environmental mechanisms and puzzles (Rensei.Puzzles). PER-PLAYER: the server keeps
-- each player's mechanism states; Remotes.PuzzleRemote sends a player only their own states and
-- their client draws them (steam, fire, doors, blockers -- client-side collision works because each
-- player's character physics is theirs).
-- Ways a state changes (all server-checked):
--   * alchemy: AlchemyService calls React(Player, Element, Position, Direction) when a move goes
--     active; mechanisms in range with a Reaction for that element respond
--   * prompts: take coal / feed coal / open a minigame (MinigameService calls OnMinigamePassed)
--   * standing on a plate (checked every 0.25s)
--   * melee: HitboxManager.Sweep calls Strike(Player, Position, Heavy) for each of a player's strikes; a
--     Breakable mechanism (boards) breaks after Def.Hits of them (2026-10-20)
-- A mechanism with Party = true shares a player's break with their party members in this server.
-- Timed states revert by themselves (failures are recoverable). Permanent states (a sealed vent)
-- and solved puzzles are saved (Story.Flags["Mech_<Id>"], Story.Puzzles) and restored on rejoin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Content = require(ReplicatedStorage.Modules.Data.Rensei.Puzzles)
local ProgressionService = require(ServerScriptService.ProgressionService)
local QuestService = require(ServerScriptService.QuestService)
local UIService = require(ServerScriptService.UIService)

local TAG = "RenseiMechanism"
local PROMPT_DISTANCE = 12

local PuzzleService = {}

local Remote
local States = {} -- [Player] = {[MechanismId] = {State, Until}} (plain table; cleared on leave)
local Strikes = {} -- [Player] = {[MechanismId] = melee hits so far} (Breakable; cleared on leave / state change)
local STRIKE_RANGE = 7 -- studs from a strike's hitbox centre to the nearest part of the boards (PROPOSAL)
local Instances = {} -- [MechanismId] = {Instance, ...} (a mechanism may exist more than once)

local function PartOf(Inst)
	if Inst:IsA("BasePart") then return Inst end
	if Inst:IsA("Model") then return Inst.PrimaryPart or Inst:FindFirstChildWhichIsA("BasePart", true) end
end

local function Mine(Player)
	States[Player] = States[Player] or {}
	return States[Player]
end

function PuzzleService.StateOf(Player, Id)
	local Def = Content.Mechanisms[Id]
	local S = Mine(Player)[Id]
	return S and S.State or (Def and Def.Default)
end

local function Snapshot(Player)
	local Out = {}
	for Id in pairs(Content.Mechanisms) do Out[Id] = PuzzleService.StateOf(Player, Id) end
	return Out
end

local function Send(Player, Id)
	if not Remote then return end
	local S = Mine(Player)[Id]
	Remote:FireClient(Player, "State", Id, PuzzleService.StateOf(Player, Id), S and S.Until or nil)
end

local function Say(Player, Text)
	if Text then UIService.Notify(Player, "Toast", {Text = Text}) end
end

-- ===== solving =====
local function CheckPuzzles(Player, ChangedId)
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	local S = Snapshot(Player)
	for PuzzleId, P in pairs(Content.Puzzles) do
		if not Data.Story.Puzzles[PuzzleId] and table.find(P.Mechanisms, ChangedId) and P.Solved(S) then
			Data.Story.Puzzles[PuzzleId] = os.time()
			UIService.Notify(Player, "Banner", {Text = P.OpenText or (P.Title .. " solved")})
			if Remote then Remote:FireClient(Player, "Solved", PuzzleId) end
			QuestService.Signal(Player, "Puzzle", PuzzleId)
			ProgressionService.Sync(Player)
		end
	end
end

-- For = seconds (nil = stays); Permanent = save it
function PuzzleService.SetState(Player, Id, State, For, Permanent)
	local Def = Content.Mechanisms[Id]
	if not Def then return false end
	local Mech = Mine(Player)
	local Was = PuzzleService.StateOf(Player, Id)
	-- a permanent state never gets downgraded by a timed one
	local Data = ProgressionService.GetData(Player)
	if Data and Data.Story.Flags["Mech_" .. Id] and not Permanent then return false end
	Mech[Id] = {State = State, Until = For and (workspace:GetServerTimeNow() + For) or nil}
	if Strikes[Player] then Strikes[Player][Id] = nil end -- a new state starts the hit count over
	if Permanent and Data then
		Data.Story.Flags["Mech_" .. Id] = State
		ProgressionService.Sync(Player)
	end
	Send(Player, Id)
	if Was ~= State then QuestService.Signal(Player, "Mechanism", Id .. ":" .. State) end
	CheckPuzzles(Player, Id)
	return true
end

-- Party = true: the same saved state for the breaker's party members who are in this server
local function ShareWithParty(Player, Id, State)
	local Def = Content.Mechanisms[Id]
	if not (Def and Def.Party) then return end
	local Module = ServerScriptService:FindFirstChild("PartyService")
	local Ok, Party = pcall(function() return Module and require(Module).Get(Player) end)
	if not Ok or type(Party) ~= "table" then return end
	for _, Member in ipairs(Party.Members or {}) do
		if Member ~= Player and Member.Parent == Players then
			local Had = States[Member] and States[Member][Id]
			if not (Had and Had.State == State) then PuzzleService.SetState(Member, Id, State, nil, true) end
		end
	end
end

-- ===== alchemy reactions =====
-- Mechanisms this element reacts with near Position (used by AlchemyService for free puzzle casts)
local function InRange(Part, Position, Direction)
	local Offset = Part.Position - Position
	local Flat = Vector3.new(Offset.X, 0, Offset.Z)
	if Flat.Magnitude <= Content.NearRange then return true end
	if Flat.Magnitude > Content.Range then return false end
	local D = Direction and Vector3.new(Direction.X, 0, Direction.Z)
	return D == nil or D.Magnitude < 1e-3 or D.Unit:Dot(Flat.Unit) > 0.35
end

function PuzzleService.ReactsNear(Element, Position)
	for Id, Def in pairs(Content.Mechanisms) do
		if Def.Reactions and Def.Reactions[Element] then
			for _, Inst in ipairs(Instances[Id] or {}) do
				local Part = PartOf(Inst)
				if Part and (Part.Position - Position).Magnitude <= Content.Range then return true end
			end
		end
	end
	return false
end

function PuzzleService.React(Player, Element, Position, Direction)
	for Id, Def in pairs(Content.Mechanisms) do
		local R = Def.Reactions and Def.Reactions[Element]
		local No = Def.Refuse and Def.Refuse[Element]
		if R or No then
			for _, Inst in ipairs(Instances[Id] or {}) do
				local Part = PartOf(Inst)
				if Part and InRange(Part, Position, Direction) then
					if R then
						if PuzzleService.StateOf(Player, Id) ~= R.State or R.For then
							if PuzzleService.SetState(Player, Id, R.State, R.For, R.Permanent) then
								Say(Player, R.Text)
								if R.Permanent then ShareWithParty(Player, Id, R.State) end
							end
						end
					else
						Say(Player, No)
					end
					break
				end
			end
		end
	end
end

-- ===== melee: Breakable mechanisms =====
-- the distance from Position to the nearest point of any part of Inst
local function Gap(Inst, Position)
	local Best = math.huge
	local Parts = Inst:IsA("BasePart") and {Inst} or Inst:GetDescendants()
	for _, P in ipairs(Parts) do
		if P:IsA("BasePart") then
			local L = P.CFrame:PointToObjectSpace(Position)
			local H = P.Size / 2
			local Near = Vector3.new(math.clamp(L.X, -H.X, H.X), math.clamp(L.Y, -H.Y, H.Y), math.clamp(L.Z, -H.Z, H.Z))
			Best = math.min(Best, (L - Near).Magnitude)
		end
	end
	return Best
end

-- HitboxManager.Sweep, once per strike of a player's attack (Position = the hitbox centre, server-side).
-- Each strike within STRIKE_RANGE of a Breakable the player still has Whole counts 1 (a heavy 2); every hit
-- before the break sends that player a "Cracked" cue; Def.Hits of them break it (saved, shared with the party).
function PuzzleService.Strike(Player, Position, Heavy)
	if typeof(Position) ~= "Vector3" then return end
	for Id, Def in pairs(Content.Mechanisms) do
		if Def.Kind == "Breakable" and Def.Hits and PuzzleService.StateOf(Player, Id) == "Whole" then
			for _, Inst in ipairs(Instances[Id] or {}) do
				if Gap(Inst, Position) <= STRIKE_RANGE then
					local Count = Strikes[Player] or {}
					Strikes[Player] = Count
					Count[Id] = (Count[Id] or 0) + (Heavy and 2 or 1)
					if Count[Id] >= Def.Hits then
						if PuzzleService.SetState(Player, Id, "Broken", nil, true) then
							Say(Player, Def.BreakText)
							ShareWithParty(Player, Id, "Broken")
						end
					elseif Remote then
						Remote:FireClient(Player, "Cracked", Id, Position)
					end
					break
				end
			end
		end
	end
end

-- ===== prompts =====
local function Prompted(Player, Id, Inst)
	local Def = Content.Mechanisms[Id]
	local P = Def and Def.Prompt
	local Part = PartOf(Inst)
	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not P or not Part or not Root or (Part.Position - Root.Position).Magnitude > PROMPT_DISTANCE then return end
	if Character:GetAttribute("InCombat") then Say(Player, "You can't do that in combat") return end
	if P.Gives then
		Character:SetAttribute(P.Gives, true)
		Say(Player, P.Text)
	elseif P.Minigame then
		if PuzzleService.StateOf(Player, P.Target) == P.PassState then Say(Player, "It's already done.") return end
		require(ServerScriptService.MinigameService).Open(Player, P.Minigame, {Mechanism = P.Target, PassState = P.PassState})
	elseif P.Toggle then
		-- a lever / sluice with two positions (Forgotten Sites): each use flips it
		local Next = PuzzleService.StateOf(Player, Id) == P.Toggle[1] and P.Toggle[2] or P.Toggle[1]
		PuzzleService.SetState(Player, Id, Next)
		if P.Text then Say(Player, P.Text:format(Next:lower())) end
	elseif P.Reward then
		-- a one-time cache (Forgotten Sites): once per character, only after its puzzle is solved (checked
		-- here, not by the client-side door), paid through QuestService's reward code
		local Data = ProgressionService.GetData(Player)
		if not Data then return end
		local Flag = "Cache_" .. Id
		if Data.Story.Flags[Flag] then Say(Player, P.Empty or "It's empty now.") return end
		if P.AfterPuzzle and not Data.Story.Puzzles[P.AfterPuzzle] then Say(Player, P.Locked or "You can't reach it yet.") return end
		Data.Story.Flags[Flag] = os.time()
		QuestService.Grant(Player, P.Reward, "Exploration")
		if P.Evidence then require(ServerScriptService.StoryService).GiveEvidence(Player, P.Evidence) end
		QuestService.Signal(Player, "Signal", Flag)
		ProgressionService.Sync(Player)
		Say(Player, P.Text or "You take what's inside.")
	elseif P.State then
		if PuzzleService.StateOf(Player, Id) == P.State then Say(Player, "It's already done.") return end
		if P.Need and not Character:GetAttribute(P.Need) then Say(Player, P.Missing) return end
		if P.Need then Character:SetAttribute(P.Need, nil) end
		PuzzleService.SetState(Player, Id, P.State)
	end
end

-- MinigameService, after a server-validated pass
function PuzzleService.OnMinigamePassed(Player, Context)
	if type(Context) == "table" and Context.Mechanism and Content.Mechanisms[Context.Mechanism] then
		PuzzleService.SetState(Player, Context.Mechanism, Context.PassState, nil, true)
	end
end

local function Attach(Inst)
	if not CollectionService:HasTag(Inst, TAG) then return end
	local Id = Inst:GetAttribute("MechanismId")
	local Def = Content.Mechanisms[Id]
	local Part = PartOf(Inst)
	if not Def or not Part then
		warn("PuzzleService: mechanism", Inst:GetFullName(), "has unknown MechanismId", Id)
		return
	end
	Instances[Id] = Instances[Id] or {}
	if table.find(Instances[Id], Inst) then return end
	table.insert(Instances[Id], Inst)
	Inst.Destroying:Once(function()
		local I = table.find(Instances[Id], Inst)
		if I then table.remove(Instances[Id], I) end
	end)
	if Def.Prompt then
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "MechanismPrompt"
		Prompt.ActionText = Def.Prompt.Action
		Prompt.ObjectText = Def.Title or ""
		Prompt.MaxActivationDistance = 9
		Prompt.RequiresLineOfSight = false
		Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI
		Prompt.Parent = Part
		Prompt.Triggered:Connect(function(Player) Prompted(Player, Id, Inst) end)
	end
end

-- ===== per-player lifecycle =====
local function Restore(Player)
	-- permanent mechanism states and solved puzzles come back from the save
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	for Id in pairs(Content.Mechanisms) do
		local Saved = Data.Story.Flags["Mech_" .. Id]
		if Saved then Mine(Player)[Id] = {State = Saved} end
	end
end

local function SyncAll(Player)
	if not Remote then return end
	local Data = ProgressionService.GetData(Player)
	local Solved = {}
	for Id in pairs((Data and Data.Story.Puzzles) or {}) do table.insert(Solved, Id) end
	Remote:FireClient(Player, "Sync", Snapshot(Player), Solved)
end

function PuzzleService.Start()
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "PuzzleRemote"
	Remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Remote.OnServerEvent:Connect(function(Player, Kind)
		if Kind == "Sync" then
			if not States[Player] then Restore(Player) end
			SyncAll(Player)
		end
	end)
	for _, Inst in ipairs(CollectionService:GetTagged(TAG)) do Attach(Inst) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(Inst) task.defer(Attach, Inst) end)

	Players.PlayerRemoving:Connect(function(Player) States[Player] = nil Strikes[Player] = nil end)
	Players.PlayerAdded:Connect(function(Player)
		Player.CharacterAdded:Connect(function(Character)
			-- carried things don't survive a death
			Character:SetAttribute("CarryingCoal", nil)
		end)
	end)

	-- timed states revert; plates follow whoever stands on them
	task.spawn(function()
		while true do
			task.wait(0.25)
			local Now = workspace:GetServerTimeNow()
			for Player, Mech in pairs(States) do
				if Player.Parent then
					local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
					for Id, Def in pairs(Content.Mechanisms) do
						if Def.Stand and Root then
							for _, Inst in ipairs(Instances[Id] or {}) do
								local Part = PartOf(Inst)
								local L = Part and Part.CFrame:PointToObjectSpace(Root.Position)
								if L and math.abs(L.X) <= Part.Size.X / 2 + 0.5 and math.abs(L.Z) <= Part.Size.Z / 2 + 0.5 and L.Y > 0 and L.Y < 6 then
									local S = Mech[Id]
									if not (S and S.State == Def.Stand.State and S.Until and S.Until - Now > Def.Stand.For / 2) then
										if S and S.State == Def.Stand.State and S.Until then
											S.Until = math.max(S.Until, Now + Def.Stand.For) -- keep holding quietly
										else
											PuzzleService.SetState(Player, Id, Def.Stand.State, Def.Stand.For)
										end
									end
								end
							end
						end
						local S = Mech[Id]
						if S and S.Until and S.Until <= Now then
							Mech[Id] = nil
							Send(Player, Id)
						end
					end
				end
			end
		end
	end)
end

return PuzzleService

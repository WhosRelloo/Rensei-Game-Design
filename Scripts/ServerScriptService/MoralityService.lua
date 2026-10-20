-- MoralityService: the only writer of the save's Morality (Morality and Reputation Proposal.md,
-- owner approved the defaults 2026-10-16).
--   * Record(Player, DeedId): adds a deed (Rensei.Deeds) to the ledger ONCE (repeatables: at most
--     Repeat.Cap times a day) and applies it: Conduct and Trust always; Standing for Local / Public
--     deeds; Renown for Public ones. A Private deed's Standing waits until it is discovered (later).
--   * The tracks are caches: Rebuild() recomputes them from the ledger on every join, so a balance
--     change never needs a hand-edited save and every number has a cause.
--   * On join, quest outcomes already chosen (Outcome_<QuestId> + Outcomes[x].Deeds) are recorded
--     (idempotent), so saves from before schema 4 get their deeds.
--   * Combat: gripping a knocked enemy records its Finishers.Grip deed; carrying one alive to an NPC
--     with attribute TakesPrisoners records Finishers.Deliver and counts as the defeat.
--   * Places (2026-10-19, schema 5): Standing and Renown count only where a deed has been heard
--     (Rensei.Reputation). A Local / Public deed is heard at once by the factions where it happened, if
--     anyone perceived it; RumourService carries the word on. Birth deeds (born_<Origin>) are heard
--     everywhere. Old saves are seeded once so nothing they had is lost.
-- Players see words only: a quiet toast with the deed's reason, and a banner when a faction's tier
-- changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Deeds = require(Rensei.Deeds)
local Factions = require(Rensei.Factions)
local Regions = require(Rensei.Regions)
local Reputation = require(Rensei.Reputation)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local DELIVER_RANGE = 10 -- studs from a TakesPrisoners NPC (PROPOSAL)

local MoralityService = {}

local function Ensure(Data)
	Data.Morality = Data.Morality or {}
	local M = Data.Morality
	for _, K in ipairs({"Deeds", "Conduct", "Standing", "Trust", "Taboo", "Places", "Rumours", "Heat", "News"}) do M[K] = M[K] or {} end
	M.Renown = M.Renown or 0
	return M
end

local function Add(Map, Deltas, Times)
	for K, V in pairs(Deltas or {}) do Map[K] = (Map[K] or 0) + V * Times end
end

-- Conduct and Trust are personal: they move at once, wherever you are. Standing and Renown come from where
-- the deed has been heard (Rensei.Reputation): see Record and RumourService.
local function ApplyPersonal(M, Def, Times)
	Add(M.Conduct, Def.Conduct, Times)
	Add(M.Trust, Def.Trust, Times)
end

-- Recompute every cache from the ledger and the places that heard each deed.
function MoralityService.Rebuild(Data)
	local M = Ensure(Data)
	M.Conduct, M.Trust = {}, {}
	for Id, E in pairs(M.Deeds) do
		local Def = Deeds[Id]
		if type(Def) == "table" and Def.Text then ApplyPersonal(M, Def, E.Count or 0) end
	end
	M.Standing = Reputation.GlobalStanding(M, Deeds)
	M.Renown = Reputation.Renown(M, Deeds)
	return M
end

local function Tiers(M)
	local Out = {}
	for _, F in ipairs(Factions.Order) do Out[F] = Factions.TierOf(M.Standing[F]) end
	return Out
end

-- function(Player, DeedId, Def, Info = {Region, Strength, Scope, Witnesses}) after a deed counts.
-- Witnesses = WitnessService.Capture's result ({Npcs, Players, Strength}) when the deed was recorded with
-- Ctx.Witness, else nil (HeatService: an agent who saw it raises Heat at once).
MoralityService.Recorded = {}

-- the region a character stands in (Rensei.Regions; outside every area volume = the City)
function MoralityService.RegionOf(Character)
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not Root then return Regions.Default end
	local Ok, Area = pcall(function() return require(ServerScriptService.WorldService).AreaAt(Root.Position) end)
	return Regions.OfArea(Ok and Area and Area:GetAttribute("AreaName") or nil)
end

-- how many witnesses' worth a deed has when nobody was captured (dialogue / quest deeds: the people you
-- spoke to). PROPOSAL: Local 2, Public 4, Private 0.
local DEFAULT_STRENGTH = {Local = 2, Public = 4, Private = 0}

-- Returns true if the deed counted (false: unknown, already recorded, or today's cap reached).
-- Ctx (optional): Region (where it happened; default: where the player stands), Strength (witness weight),
-- Witness (true: capture who perceived it, WitnessService), Evidence (items left behind).
function MoralityService.Record(Player, DeedId, Quiet, Ctx)
	local Def = Deeds[DeedId]
	local Data = ProgressionService.GetData(Player)
	if type(Def) ~= "table" or not Def.Text or not Data then return false end
	Ctx = Ctx or {}
	local M = Ensure(Data)
	local E = M.Deeds[DeedId]
	if E and not Def.Repeat then return false end -- once ever
	E = E or {At = os.time(), Count = 0, Seen = 0}
	E.Seen += 1
	E.Last = os.time()
	if Def.Repeat then
		local Today = math.floor(os.time() / 86400)
		if E.Day ~= Today then E.Day, E.DayCount = Today, 0 end
		if E.DayCount >= (Def.Repeat.Cap or 1) then
			M.Deeds[DeedId] = E
			return false -- seen, but it no longer moves anything today (no farming)
		end
		E.DayCount += 1
	end
	E.Count += 1
	M.Deeds[DeedId] = E
	local Before = Tiers(M)
	ApplyPersonal(M, Def, 1)
	-- where it's heard: a birth deed everywhere; a Local / Public one by the factions where it happened, if
	-- anyone perceived it (word then travels: RumourService); a Private one nowhere until discovered
	local Scope = E.Known or Def.Scope or "Private"
	local Region = Ctx.Region
	if not Regions.Regions[Region or ""] then Region = MoralityService.RegionOf(Player.Character) end
	local Strength = tonumber(Ctx.Strength)
	local Witnesses = nil
	if Strength == nil and Ctx.Witness then
		local Ok, W = pcall(function()
			return require(ServerScriptService.WitnessService).Capture(Player, DeedId, tonumber(Ctx.Evidence) or 0)
		end)
		if Ok and type(W) == "table" then
			Witnesses, Strength = W, tonumber(W.Strength)
		else
			warn("MoralityService: witness capture failed for", DeedId, W)
			Strength = DEFAULT_STRENGTH.Local
		end
	end
	Strength = Strength or DEFAULT_STRENGTH[Scope] or 0
	local Now = os.time()
	if Def.Birth then
		Reputation.LandEverywhere(M, DeedId, Now)
	elseif Scope ~= "Private" and Strength > 0 then
		Reputation.Land(M, Region, DeedId, Regions.FactionsAt(Region), Now)
	end
	M.Standing = Reputation.GlobalStanding(M, Deeds)
	M.Renown = Reputation.Renown(M, Deeds)
	if Def.Bonus and (Def.Bonus.Money or 0) > 0 then ProgressionService.GrantMoney(Player, Def.Bonus.Money) end
	if not Quiet then
		UIService.Notify(Player, "Toast", {Text = Def.Text})
		local After = Tiers(M)
		for _, F in ipairs(Factions.Order) do
			if After[F] ~= Before[F] then
				UIService.Notify(Player, "Banner", {Text = Factions.Factions[F].Name .. " - " .. After[F]})
			end
		end
	end
	ProgressionService.Sync(Player)
	local Info = {Region = Region, Strength = Strength, Scope = Scope, Witnesses = Witnesses}
	for _, Listener in ipairs(MoralityService.Recorded) do task.spawn(Listener, Player, DeedId, Def, Info) end
	return true
end

-- Caches rebuilt after word arrived somewhere (RumourService): banners for any tier that changed.
function MoralityService.Refresh(Player)
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	local M = Ensure(Data)
	local Before = Tiers(M)
	MoralityService.Rebuild(Data)
	local After = Tiers(M)
	for _, F in ipairs(Factions.Order) do
		if After[F] ~= Before[F] then
			UIService.Notify(Player, "Banner", {Text = Factions.Factions[F].Name .. " - " .. After[F]})
		end
	end
	ProgressionService.Sync(Player)
end

-- The origin's birth deed (Identity.Origin, set at character creation in the menu): once, quietly.
function MoralityService.RecordBirth(Player)
	local Data = ProgressionService.GetData(Player)
	local Origin = Data and Data.Identity and Data.Identity.Origin
	if type(Origin) ~= "string" or Origin == "" or not Deeds["born_" .. Origin] then return false end
	return MoralityService.Record(Player, "born_" .. Origin, true)
end

function MoralityService.Has(Player, DeedId)
	local Data = ProgressionService.GetData(Player)
	return Data ~= nil and Data.Morality ~= nil and Data.Morality.Deeds[DeedId] ~= nil
end

-- Deeds for an outcome the player already chose (quest Outcomes[x].Deeds). Idempotent.
function MoralityService.RecordOutcomes(Player, Quiet)
	local Data = ProgressionService.GetData(Player)
	if not Data or not Data.Story then return end
	local Quests = require(Rensei.Quests)
	for QuestId, Def in pairs(Quests) do
		local Outcome = Def.Outcomes and Data.Story.Flags["Outcome_" .. QuestId]
		local O = Outcome and Def.Outcomes[Outcome]
		if O and Data.Quests.Completed[QuestId] then
			for _, Id in ipairs(O.Deeds or {}) do MoralityService.Record(Player, Id, Quiet) end
		end
	end
end

-- ===== combat: grip vs deliver =====
local function FinisherOf(Model)
	return Model and not Players:GetPlayerFromCharacter(Model) and Deeds.Finishers[Model:GetAttribute("EnemyType") or ""]
end

-- DownedManager.Listeners: a grip finished a knocked target
local function OnGrip(Gripper, Target)
	local Player = Players:GetPlayerFromCharacter(Gripper)
	local F = Player and FinisherOf(Target)
	if F and F.Grip then MoralityService.Record(Player, F.Grip, false, {Witness = true}) end
end

local function Captors()
	local Out = {}
	local NPCs = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("NPCs")
	for _, M in ipairs(NPCs and NPCs:GetChildren() or {}) do
		local R = M:IsA("Model") and M:GetAttribute("TakesPrisoners") and M:FindFirstChild("HumanoidRootPart")
		if R then table.insert(Out, R) end
	end
	return Out
end

-- A player carrying a knocked enemy into range of a TakesPrisoners NPC hands them over.
local function CheckDeliveries()
	local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
	local Takers = Captors()
	if #Takers == 0 then return end
	for _, Player in ipairs(Players:GetPlayers()) do
		local Character = Player.Character
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		local Target = Character and DownedManager.Carried(Character)
		local F = Target and FinisherOf(Target)
		if Root and F and F.Deliver then
			for _, T in ipairs(Takers) do
				if (T.Position - Root.Position).Magnitude <= DELIVER_RANGE then
					DownedManager.Drop(Character)
					Target:SetAttribute("Arrested", true) -- WorldService: credit once, to the deliverer
					require(ServerScriptService.WorldService).Credit(Target, Player)
					MoralityService.Record(Player, F.Deliver)
					UIService.Notify(Player, "Toast", {Text = (T.Parent:GetAttribute("DisplayName") or T.Parent.Name) .. " takes the prisoner."})
					-- led away: gone from the yard (EnemyService respawns it as after a death)
					for _, D in ipairs(Target:GetDescendants()) do
						if D:IsA("BasePart") or D:IsA("Decal") then D.Transparency = 1 end
					end
					local H = Target:FindFirstChildOfClass("Humanoid")
					if H then H.Health = 0 end
					break
				end
			end
		end
	end
end

function MoralityService.Start()
	table.insert(require(ReplicatedStorage.Modules.Managers.DownedManager).Listeners, function(Kind, Actor, Target)
		if Kind == "Grip" then OnGrip(Actor, Target) end
	end)
	local function Joined(Player)
		-- the profile loads asynchronously; wait for it, then rebuild and catch up on old choices
		for _ = 1, 60 do
			if not Player.Parent then return end
			local Data = ProgressionService.GetData(Player)
			if Data then
				local M = Ensure(Data)
				Reputation.Seed(M, Deeds, os.time()) -- schema 5: old deeds heard everywhere, once
				MoralityService.RecordBirth(Player)
				MoralityService.Rebuild(Data)
				MoralityService.RecordOutcomes(Player, true)
				-- word that travelled while they were away (offline catch-up)
				local Ok, Err = pcall(function() require(ServerScriptService.RumourService).Tick(Player) end)
				if not Ok then warn("MoralityService: rumour catch-up on join failed:", Err) end
				ProgressionService.Sync(Player)
				return
			end
			task.wait(0.5)
		end
	end
	for _, Player in ipairs(Players:GetPlayers()) do task.spawn(Joined, Player) end
	Players.PlayerAdded:Connect(Joined)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local Ok, Err = pcall(CheckDeliveries)
			if not Ok then warn("MoralityService deliveries:", Err) end
		end
	end)
end

return MoralityService

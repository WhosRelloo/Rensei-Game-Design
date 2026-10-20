-- HeatService (2026-10-20, Morality × Reputation spec §6 / §7; Plan 2, slice R3): Heat and Wanted. The only
-- writer of the save's Morality.Heat (the maths is Rensei.Heat).
--   * A crime (Rensei.Deeds: Crime / CircleHeat) raises Heat:
--       - at once, when one of that law's agents saw it (WitnessService: Carrier, Faction = Heat.Law[J]), or when
--         the law's faction is present where it happened (the deed is heard there at once);
--       - otherwise when word of it reaches a place whose law hears it (RumourService arrivals).
--     Each crime raises each jurisdiction once: a rumour remembers which ones it already raised (R.Heated).
--   * Wanted 0-5 per jurisdiction (Heat.Thresholds), published as Player attributes Wanted_<J> / Heat_<J> for
--     the HUD, with a banner when it changes. Heat decays -5 per hour of real time (offline too).
--   * Getting clear here: Fine (a State desk: Foreman Brask's dialogue, Wanted <= 2, 100 x level). The cell,
--     pardons, bribes and safehouses come with later plans.
--   * Crimes recorded here: unlicensed casting (OnCast, from AlchemyService) and assault (a hit on a watcher).
-- Every number is a PROPOSAL.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Heat = require(Rensei.Heat)
local Deeds = require(Rensei.Deeds)
local Regions = require(Rensei.Regions)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local HeatService = {}
HeatService.LicenceLevel = 6 -- from this level, casting without a licence is a crime (spec §7)
HeatService.AssaultCooldown = 30 -- seconds: one assault per victim per attacker
HeatService.RefreshSeconds = 30

local Clock = os.time
function HeatService.SetClock(Fn) Clock = Fn or os.time end
function HeatService.Now() return Clock() end

local function Data(Player) return ProgressionService.GetData(Player) end

local function HeatTable(Player)
	local D = Data(Player)
	if not D then return nil end
	D.Morality = D.Morality or {}
	D.Morality.Heat = D.Morality.Heat or {}
	return D.Morality.Heat
end

function HeatService.Value(Player, J) return Heat.ValueOf(HeatTable(Player), J, Clock()) end
function HeatService.Wanted(Player, J) return Heat.WantedOf(HeatTable(Player), J, Clock()) end

-- the HUD's attributes and a banner when a Wanted level changes
function HeatService.Publish(Player, Quiet)
	local H = HeatTable(Player)
	if not H then return end
	local Now = Clock()
	for _, J in ipairs(Heat.Order) do
		local V = Heat.ValueOf(H, J, Now)
		local W = Heat.Wanted(V)
		local Old = Player:GetAttribute("Wanted_" .. J)
		Player:SetAttribute("Heat_" .. J, math.floor(V * 10 + 0.5) / 10)
		Player:SetAttribute("Wanted_" .. J, W)
		if not Quiet and Old ~= nil and Old ~= W then
			UIService.Notify(Player, "Banner", {Text = W > 0 and (Heat.Names[J] .. " - Wanted " .. W) or (Heat.Names[J] .. " - no longer wanted")})
		end
	end
end

-- adds Heat (Cap per region per hour when given); returns what was added
function HeatService.Add(Player, J, Amount, Region, Cap)
	local H = HeatTable(Player)
	if not H or not Heat.Law[J] or type(Amount) ~= "number" or Amount <= 0 then return 0 end
	local Added = Heat.Add(H, J, Amount, Clock(), Region, Cap)
	if Added > 0 then
		HeatService.Publish(Player)
		ProgressionService.Sync(Player)
	end
	return Added
end

function HeatService.Clear(Player, J)
	local H = HeatTable(Player)
	if not H then return end
	Heat.Clear(H, J, Clock())
	HeatService.Publish(Player)
	ProgressionService.Sync(Player)
end

-- the fine at a State desk: Wanted <= 2, costs 100 x level, State Heat -> 0. Returns ok, message.
function HeatService.Fine(Player, J)
	J = J or "State"
	local D = Data(Player)
	if not D then return false, nil end
	local V = HeatService.Value(Player, J)
	if V <= 0 then return false, "You owe nothing." end
	if Heat.Wanted(V) > Heat.FineMaxWanted then return false, "It's past a fine now." end
	local Cost = Heat.FinePerLevel * math.max(1, D.Level or 1)
	if not ProgressionService.SpendMoney(Player, Cost) then return false, ("The fine is %d. You don't have it."):format(Cost) end
	HeatService.Clear(Player, J)
	return true, ("Paid a fine of %d."):format(Cost)
end

-- ===== where Heat comes from =====

-- a deed was recorded: Heat at once for each law that saw it (an agent) or that is present where it happened
local function OnRecorded(Player, DeedId, Def, Info)
	if not Def.Crime and not Def.CircleHeat then return end
	local RegionDef = Regions.Regions[Info.Region]
	if not RegionDef then return end
	local Heard = {}
	-- heard where it happened (MoralityService lands it there when someone perceived it)
	if Info.Scope ~= "Private" and (Info.Strength or 0) > 0 then
		for _, F in ipairs(Regions.FactionsAt(Info.Region)) do table.insert(Heard, F) end
	end
	-- an agent who saw it reports at once, even where its faction isn't present
	for _, W in ipairs((Info.Witnesses and Info.Witnesses.Npcs) or {}) do
		if W.Carrier and W.Faction and not table.find(Heard, W.Faction) then table.insert(Heard, W.Faction) end
	end
	local Raised = Heat.Raised(RegionDef, Heard, Def)
	if #Raised == 0 then return end
	-- the live rumour of this deed from here remembers what it already raised (RumourService spawned it first)
	local M = Data(Player) and Data(Player).Morality
	local Rumour = nil
	for _, R in ipairs((M and M.Rumours) or {}) do
		if R.Deed == DeedId and R.Origin == Info.Region and not R.Suppressed then Rumour = R end
	end
	for _, X in ipairs(Raised) do
		HeatService.Add(Player, X.J, X.Amount, Info.Region, Def.HeatCap)
		if Rumour then Rumour.Heated = Rumour.Heated or {}; Rumour.Heated[X.J] = true end
	end
end

-- word of a deed arrived somewhere (RumourService.Tick; Core.Advance's Landings): Heat where that place's law
-- heard it, once per rumour. Reach = every faction the carrier reaches there, not only those hearing the deed
-- for the first time, so a repeat crime (a new rumour) still raises Heat.
function HeatService.OnArrivals(Player, Landings)
	for _, A in ipairs(Landings) do
		local R = A.Rumour
		local Def = Deeds[R.Deed]
		local RegionDef = Regions.Regions[A.Place]
		if type(Def) == "table" and RegionDef then
			for _, X in ipairs(Heat.Raised(RegionDef, A.Reach or A.Heard or {}, Def)) do
				R.Heated = R.Heated or {}
				if not R.Heated[X.J] then
					R.Heated[X.J] = true
					HeatService.Add(Player, X.J, X.Amount, A.Place, Def.HeatCap)
				end
			end
		end
	end
end

-- Authority agents who saw this player within the last few seconds (PerceptionService)
local function AgentsWatching(Player)
	local Out = {}
	local Ok, PS = pcall(function() return require(ServerScriptService.PerceptionService) end)
	if not Ok then return Out end
	for _, S in ipairs(PS.Perceived(Player)) do
		if S.Carrier and S.Faction == Heat.Law.State then table.insert(Out, S) end
	end
	return Out
end
HeatService.AgentsWatching = AgentsWatching

-- AlchemyService: a player's cast went off. From level 6, without a State licence, in a State place, in front
-- of an Authority agent: the crime unlicensed_cast. Returns true if it was recorded.
function HeatService.OnCast(Player)
	local D = Data(Player)
	if not D or (D.Level or 1) < HeatService.LicenceLevel then return false end
	if D.Licence and D.Licence.Path == "State" then return false end
	local MS = require(ServerScriptService.MoralityService)
	local Region = MS.RegionOf(Player.Character)
	local RegionDef = Regions.Regions[Region]
	if not RegionDef or RegionDef.Jurisdiction ~= "State" then return false end
	if #AgentsWatching(Player) == 0 then return false end
	return MS.Record(Player, "unlicensed_cast", false, {Witness = true, Region = Region})
end

-- a hit on a watcher (a townsperson, tag RenseiWatcher) is assault: once per victim per 30 s
local LastAssault = {} -- [Player] = {[Victim] = os.clock()}
local function OnHit(Attacker, Victim)
	local Player = Players:GetPlayerFromCharacter(Attacker)
	if not Player or not Victim or not CollectionService:HasTag(Victim, "RenseiWatcher") then return end
	local Mine = LastAssault[Player] or setmetatable({}, {__mode = "k"})
	LastAssault[Player] = Mine
	if Mine[Victim] and os.clock() - Mine[Victim] < HeatService.AssaultCooldown then return end
	Mine[Victim] = os.clock()
	require(ServerScriptService.MoralityService).Record(Player, "assault_townsfolk", false, {Witness = true})
end

function HeatService.Start()
	table.insert(require(ServerScriptService.MoralityService).Recorded, OnRecorded)
	table.insert(ProgressionService.HitListeners, OnHit)
	Players.PlayerRemoving:Connect(function(Player) LastAssault[Player] = nil end)
	local function Joined(Player)
		for _ = 1, 60 do
			if not Player.Parent then return end
			if Data(Player) then HeatService.Publish(Player, true) return end
			task.wait(0.5)
		end
	end
	for _, Player in ipairs(Players:GetPlayers()) do task.spawn(Joined, Player) end
	Players.PlayerAdded:Connect(Joined)
	-- decay shows up on the HUD (and as a banner when a level drops)
	task.spawn(function()
		while true do
			task.wait(HeatService.RefreshSeconds)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Ok, Err = pcall(HeatService.Publish, Player)
				if not Ok then warn("HeatService:", Err) end
			end
		end
	end)
end

return HeatService

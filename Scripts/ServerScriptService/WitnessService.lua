-- WitnessService (2026-10-19, Morality × Reputation spec §4): who saw a deed. NPC witnesses come from
-- PerceptionService: an NPC only witnesses what it actually perceived (spec §17). Player witnesses are
-- players within Identities.WitnessRange with a clear line of sight (IdentityService's rule); they're
-- remembered here, in server memory, so they can report the deed at a desk later (RumourService.Report).
-- Strength (PROPOSAL): 1 per NPC witness, 2 per agent (Carrier: State / Circle agents), 3 per evidence.
-- No witness and no evidence = strength 0 = no rumour (a ghost).
-- Hostile NPCs (no Faction: bandits, scavengers) still notice you and are listed, but add no strength: they
-- don't talk to anyone who matters (owner default, Plan 2, 2026-10-20).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Rules = require(ReplicatedStorage.Modules.Data.Rensei.Identities)

local WitnessService = {}
WitnessService.Weights = {Npc = 1, Agent = 2, Evidence = 3}
WitnessService.ReportWindow = 30 * 60 -- a player witness may report within 30 min (PROPOSAL)

local Seen = {} -- [WitnessUserId] = {[SubjectUserId .. ":" .. DeedId] = os.time()}

function WitnessService.Strength(Npcs, Evidence)
	local S = 0
	for _, W in ipairs(Npcs) do
		if W.Faction then S += W.Carrier and WitnessService.Weights.Agent or WitnessService.Weights.Npc end
	end
	return S + (Evidence or 0) * WitnessService.Weights.Evidence
end

function WitnessService.Note(WitnessId, SubjectId, DeedId, At)
	Seen[WitnessId] = Seen[WitnessId] or {}
	Seen[WitnessId][SubjectId .. ":" .. DeedId] = At
end

function WitnessService.CanReport(WitnessId, SubjectId, DeedId, Now)
	local At = Seen[WitnessId] and Seen[WitnessId][SubjectId .. ":" .. DeedId]
	return At ~= nil and Now - At <= WitnessService.ReportWindow
end

function WitnessService.Forget(WitnessId, SubjectId, DeedId)
	if Seen[WitnessId] then Seen[WitnessId][SubjectId .. ":" .. DeedId] = nil end
end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude

function WitnessService.Capture(Player, DeedId, Evidence)
	local PerceptionService = require(ServerScriptService.PerceptionService)
	local Npcs = {}
	for _, S in ipairs(PerceptionService.Perceived(Player)) do
		table.insert(Npcs, {Rig = S.Rig, Faction = S.Faction, Carrier = S.Carrier, Type = S.Type})
	end
	local Saw = {}
	local C = Player.Character
	local Head = C and C:FindFirstChild("Head")
	if Head then
		local Now = os.time()
		for _, Other in ipairs(Players:GetPlayers()) do
			local OC = Other ~= Player and Other.Character
			local Eye = OC and OC:FindFirstChild("Head")
			if Eye and (Eye.Position - Head.Position).Magnitude <= Rules.WitnessRange then
				Rays.FilterDescendantsInstances = {C, OC}
				if not workspace:Raycast(Eye.Position, Head.Position - Eye.Position, Rays) then
					table.insert(Saw, Other)
					WitnessService.Note(Other.UserId, Player.UserId, DeedId, Now)
				end
			end
		end
	end
	return {Npcs = Npcs, Players = Saw, Strength = WitnessService.Strength(Npcs, Evidence)}
end

Players.PlayerRemoving:Connect(function(Player) Seen[Player.UserId] = nil end)

return WitnessService

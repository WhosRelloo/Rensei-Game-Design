-- RankService: the public face of each player that the leaderboard shows (HUDUI).
-- Publish(Player) reads the server's copy of the save and writes read-only attributes on the Player:
--   ProfileReady = true once the save has loaded (until then the leaderboard shows "Loading")
--   Rank (1-4, earned), Title, RankStatus (the eligibility line), StateLicense (bool),
--   Nation (the nation picked in character creation, Identity.Origin, by its Customization name;
--   "" before a character exists)
-- "Level" is already published by ProgressionService.Sync, which calls Publish, so every save change
-- that syncs (EXP, quests, flags, admin) updates the leaderboard. Attributes the server sets replicate
-- to every client; a client can change its own local copy, but that never replicates, so it fools
-- neither the server nor other players. Nothing here reads a value a client sent.
-- Promote / Demote: server-only (quest rewards and dialogue actions can set the same flags; the admin
-- panel's SetRank calls these). Promote checks the level and that the rank below is already held.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Ranks = require(ReplicatedStorage.Modules.Data.Rensei.Ranks)
local Nations = require(ReplicatedStorage.Modules.Data.Rensei.Customization).Nations
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)

local RankService = {}

local function DataOf(Player)
	local Profile = DataManager:GetProfile(Player)
	return Profile and Profile.Data
end

local function FlagsOf(Data)
	return (type(Data.Story) == "table" and type(Data.Story.Flags) == "table") and Data.Story.Flags or {}
end

local function Set(Player, Key, Value)
	if Player:GetAttribute(Key) ~= Value then Player:SetAttribute(Key, Value) end
end

function RankService.RankOf(Player)
	local Data = DataOf(Player)
	if not Data then return nil end
	return Ranks.Evaluate(Data.Level, FlagsOf(Data))
end

function RankService.Publish(Player)
	local Data = DataOf(Player)
	if not Data or not Player.Parent then return end
	local Flags = FlagsOf(Data)
	local Rank, Status = Ranks.Evaluate(Data.Level, Flags)
	local NationId = type(Data.Identity) == "table" and Data.Identity.Origin or ""
	local Nation = type(NationId) == "string" and Nations[NationId]
	Set(Player, "Rank", Rank)
	Set(Player, "Title", Ranks.List[Rank].Title)
	Set(Player, "RankStatus", Status)
	Set(Player, "StateLicense", Rank >= 2)
	-- an id the list doesn't know shows as saved, never as a made-up nation
	Set(Player, "Nation", Nation and Nation.Name or (type(NationId) == "string" and NationId or ""))
	-- the character's name (first + clan surname, filtered at creation) for the leaderboard (owner 2026-10-18)
	local Name = type(Data.Identity) == "table" and Data.Identity.Name or ""
	Set(Player, "CharacterName", type(Name) == "string" and Name or "")
	Set(Player, "ProfileReady", true)
end

-- Grants rank N (2 or 3). Idempotent: holding it already is a no-op.
function RankService.Promote(Player, N)
	local Def = Ranks.List[N]
	if not Def or not Def.Flag or Def.WIP then return false, "That rank can't be granted" end
	local Data = DataOf(Player)
	if not Data then return false, "Profile not loaded" end
	local Current = Ranks.Evaluate(Data.Level, FlagsOf(Data))
	if Current >= N then return false, "Already holds " .. Def.Title end
	if Current < N - 1 then return false, "Needs " .. Ranks.List[N - 1].Title .. " first" end
	if (tonumber(Data.Level) or 1) < Def.MinLevel then return false, ("Needs level %d"):format(Def.MinLevel) end
	require(ServerScriptService.StoryService).SetFlag(Player, Def.Flag, os.time(), true) -- saves, syncs
	RankService.Publish(Player)
	return true, Def.Title
end

-- Takes away rank N and everything above it (admin / testing).
function RankService.Demote(Player, N)
	local Data = DataOf(Player)
	if not Data then return false, "Profile not loaded" end
	local Flags = FlagsOf(Data)
	for I = math.max(2, N), #Ranks.List do
		local Def = Ranks.List[I]
		if Def.Flag then Flags[Def.Flag] = nil end
	end
	require(ServerScriptService.ProgressionService).Sync(Player)
	return true
end

function RankService.Start()
	local function Added(Player)
		task.spawn(function()
			if DataManager:WaitProfile(Player, 60) then RankService.Publish(Player) end
		end)
	end
	Players.PlayerAdded:Connect(Added)
	for _, Player in ipairs(Players:GetPlayers()) do Added(Player) end
end

return RankService

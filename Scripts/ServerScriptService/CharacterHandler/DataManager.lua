local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)

local SessionData = ProfileService.GetProfileStore("PlayerData",ProfileData)

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local Sessions = {}

-- Versioned migrations. Each step upgrades a profile by exactly one version.
local Migrations = {
	-- nil -> 1: the JJK template schema (StatTable/SkillTree/"CE" stats) becomes Rensei's.
	-- Those keys never held Rensei progress, so they are dropped rather than converted.
	[0] = function(Data)
		Data.StatTable = nil
		Data.SkillTree = nil
		Data.Race = nil
		Data.StatPoints = math.max(0, (Data.Level or 1) - 1) * 3
	end,
	-- 1 -> 2: the skill tree (AlchemyTree, never used, becomes SkillTree) + refundable stage spending.
	-- KEEP IN SYNC with the menu place's MenuData and the tutorial place's FlowData.
	[1] = function(Data)
		Data.SkillTree = Data.SkillTree or Data.AlchemyTree or {}
		Data.AlchemyTree = nil
		if Data.Mastery then Data.Mastery.StageSpend = Data.Mastery.StageSpend or {} end
	end,
	-- 2 -> 3: story state (flags, evidence, deductions, puzzles, minigames) + staged quests.
	-- Additive only. The menu / tutorial places don't need this step (they never read Story).
	[2] = function(Data)
		Data.Story = Data.Story or {}
		for _, K in ipairs({"Flags", "Evidence", "Deductions", "Puzzles", "Minigames"}) do
			Data.Story[K] = Data.Story[K] or {}
		end
		if Data.Quests then
			for _, State in pairs(Data.Quests.Active or {}) do State.Stage = State.Stage or 1 end
		end
	end,
	-- 3 -> 4: the morality ledger. Additive only; choices already made (Outcome_<QuestId> flags) are
	-- turned into their deeds by MoralityService when the player joins (it reads the quest data).
	[3] = function(Data)
		Data.Morality = Data.Morality or {}
		for _, K in ipairs({"Deeds", "Conduct", "Standing", "Trust", "Taboo"}) do
			Data.Morality[K] = Data.Morality[K] or {}
		end
		Data.Morality.Renown = Data.Morality.Renown or 0
	end,
}

local function Migrate(Data)
	local Version = Data.SchemaVersion or 0
	while Migrations[Version] do
		Migrations[Version](Data)
		Version += 1
		Data.SchemaVersion = Version
	end
end


local DataManager = {}

function DataManager:Initiate()
	local function PlayerAdded(Player)
		-- the save slot the menu picked (ServerScriptService.SlotAccount; slot 1 = the original key)
		local Key = require(game:GetService("ServerScriptService").SlotAccount).ProfileKey(Player.UserId)
		if not Player.Parent then return end
		local PlayerData = SessionData:LoadProfileAsync(Key,"ForceLoad")
		

		if not PlayerData then
			Player:Kick("Data Failed To Load")
		else
			-- Migrate BEFORE Reconcile: Reconcile would stamp the template's SchemaVersion
			-- onto an old profile and the migration would never run.
			Migrate(PlayerData.Data)
			PlayerData:Reconcile()

			if Player.Name == "<redacted>" then -- (export: a player-specific test reset; the name is not published)
				PlayerData.Data = deepCopy(ProfileData)
			end

			Sessions[Player] = PlayerData

			PlayerData:ListenToRelease(function()
				Sessions[Player] = nil
			end)
		end
	end

	local function PlayerRemoving(Player)
		local PlayerData = Sessions[Player]
		if PlayerData then
			PlayerData:Release()
		end
	end

	for I,V in pairs(Players:GetChildren()) do
		PlayerAdded(V)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

function DataManager:GetProfile(Player)
	return Sessions[Player]
end

function DataManager:SendData(Player)
	local PlayerData = DataManager:GetProfile(Player)
	
	ReplicatedStorage.Remotes.DataRemote:FireClient(Player,PlayerData.Data)
end

return DataManager

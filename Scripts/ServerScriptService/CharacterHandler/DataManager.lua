-- Player profiles in Ye (ProfileService store "PlayerData"; the menu and tutorial places use the same
-- store, see their MenuData / FlowData). The key is the save slot the menu picked
-- (ServerScriptService.SlotAccount; slot 1 = the original "Data" .. UserId).
-- * Migrate BEFORE Reconcile (ServerScriptService.ProfileMigrations, same file in every place).
-- * A profile opened by another server (its ForceLoad steals the session lock) kicks the player
--   here, so nothing is played that can't be saved. FlowService releases with DataManager:Release
--   before a teleport, which doesn't kick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local ProfileMigrations = require(ServerScriptService:WaitForChild("ProfileMigrations"))
local SlotAccount = require(ServerScriptService:WaitForChild("SlotAccount"))

local SessionData = ProfileService.GetProfileStore("PlayerData",ProfileData)

local Sessions = {}
local Leaving = {} -- [Player] = true once released for a teleport (no "opened elsewhere" kick)

local DataManager = {}

local function PlayerAdded(Player)
	-- the save slot the menu picked; nil = the account store couldn't be read (never guess slot 1)
	local Key = SlotAccount.ProfileKey(Player.UserId)
	if not Player.Parent then return end
	if not Key then
		Player:Kick("Couldn't load your save slot. Please rejoin.")
		return
	end
	local PlayerData = SessionData:LoadProfileAsync(Key,"ForceLoad")
	if not PlayerData then
		Player:Kick("Data Failed To Load")
		return
	end
	ProfileMigrations.Migrate(PlayerData.Data)
	PlayerData:Reconcile()
	if not Player.Parent then
		-- left while it loaded
		PlayerData:Release()
		return
	end
	Sessions[Player] = PlayerData
	PlayerData:ListenToRelease(function()
		-- (our own releases clear Sessions first; only a release from elsewhere finds it still open)
		if Sessions[Player] ~= PlayerData then return end
		Sessions[Player] = nil
		if Player.Parent and not Leaving[Player] then Player:Kick("Your data was opened somewhere else. Please rejoin.") end
	end)
end

function DataManager:Initiate()
	local function PlayerRemoving(Player)
		local PlayerData = Sessions[Player]
		Sessions[Player], Leaving[Player] = nil, nil
		if PlayerData then
			PlayerData:Release()
		end
	end

	for I,V in pairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, V)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

function DataManager:GetProfile(Player)
	return Sessions[Player]
end

-- Wait (up to Timeout s) for the player's profile; nil if they leave or it never loads.
function DataManager:WaitProfile(Player, Timeout)
	local Deadline = os.clock() + (Timeout or 30)
	while not Sessions[Player] and Player.Parent and os.clock() < Deadline do task.wait(0.1) end
	return Sessions[Player]
end

-- Release now (just before a teleport) so the next place's ForceLoad doesn't wait it out. Yields
-- until the release has saved (ProfileService "hop ready", at most 6 s).
function DataManager:Release(Player)
	local PlayerData = Sessions[Player]
	Leaving[Player] = true
	Sessions[Player] = nil
	if not PlayerData then return end
	local Ready = false
	PlayerData:ListenToHopReady(function() Ready = true end)
	PlayerData:Release()
	local Deadline = os.clock() + 6
	while not Ready and os.clock() < Deadline do task.wait(0.1) end
end

function DataManager:SendData(Player)
	local PlayerData = DataManager:GetProfile(Player)
	if not PlayerData then return end
	ReplicatedStorage.Remotes.DataRemote:FireClient(Player,PlayerData.Data)
end

return DataManager

-- Player profiles in Ye (ProfileService store "PlayerData"; the menu and tutorial places use the same
-- store, see their MenuData / FlowData). The key is the save slot the menu picked
-- (ServerScriptService.SlotAccount; slot 1 = the original "Data" .. UserId).
-- * Migrate BEFORE Reconcile (ServerScriptService.ProfileMigrations, same file in every place).
-- * A profile opened by another server (its ForceLoad steals the session lock) kicks the player
--   here, so nothing is played that can't be saved. FlowService releases with DataManager:Release
--   before a teleport, which doesn't kick.
-- * TestNoSave (Studio only, owner 2026-10-27): set ServerStorage's TestNoSave attribute to true in
--   Edit before Play and the session plays a MOCK copy of the save (ProfileStore.Mock, memory only),
--   so nothing it does can reach the real profile, even when Play is stopped mid-test.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local ProfileMigrations = require(ServerScriptService:WaitForChild("ProfileMigrations"))
local SlotAccount = require(ServerScriptService:WaitForChild("SlotAccount"))
-- keeps an open profile saveable (no NaN / infinite numbers or Roblox values; data-storage audit 2026-10-18)
local ProfileGuard = require(ServerScriptService:WaitForChild("ProfileGuard"))

local SessionData = ProfileService.GetProfileStore("PlayerData",ProfileData)

-- IsStudio() first, the attribute second: a live server never reads TestNoSave, so a place published
-- with it set by mistake still saves normally. Decided once, at load, so it can't change mid-session.
local NoSave = RunService:IsStudio() and ServerStorage:GetAttribute("TestNoSave") == true

local Sessions = {}
local Leaving = {} -- [Player] = true once released for a teleport (no "opened elsewhere" kick)

local DataManager = {}

local function DeepCopy(T)
	if type(T) ~= "table" then return T end
	local C = {}
	for K, V in pairs(T) do C[K] = DeepCopy(V) end
	return C
end

-- TestNoSave: the real save, read with a plain GetAsync (no session lock, no write), copied into a mock
-- profile. Not ViewProfileAsync: this legacy ProfileService's view goes through UpdateAsync, a write.
-- Returns the mock profile, or nil and the kick message: the session never falls back to the real store.
local function LoadMockCopy(Key)
	-- the store and key ProfileService uses ("PlayerData", no scope)
	local Ok, Record = pcall(function() return DataStoreService:GetDataStore("PlayerData"):GetAsync(Key) end)
	if not Ok then
		return nil, "TestNoSave: couldn't read your save, so this test session can't start. Nothing was saved."
	end
	-- a deleted slot ("PROFILE_WIPED", MenuData's wipe) or a GlobalUpdates-only stub is an empty slot to ProfileService
	-- too: the mock keeps the template (nothing is written either way)
	if Record == "PROFILE_WIPED" or (type(Record) == "table" and Record.Data == nil and Record.MetaData == nil
		and type(Record.GlobalUpdates) == "table") then
		Record = nil
	end
	if Record ~= nil and (type(Record) ~= "table" or type(Record.Data) ~= "table") then
		return nil, "TestNoSave: your save isn't in the expected shape, so this test session won't use it. Nothing was saved."
	end
	local Mock = SessionData.Mock:LoadProfileAsync(Key,"ForceLoad")
	if not Mock then
		return nil, "TestNoSave: the test copy of your save didn't load. Nothing was saved."
	end
	if Record ~= nil then
		Mock.Data = DeepCopy(Record.Data) -- a missing, wiped or stub save (an empty slot) keeps the template
	end
	return Mock
end

local function PlayerAdded(Player)
	-- the save slot the menu picked; nil = the account store couldn't be read (never guess slot 1)
	local Key = SlotAccount.ProfileKey(Player.UserId)
	if not Player.Parent then return end
	if not Key then
		Player:Kick("Couldn't load your save slot. Please rejoin.")
		return
	end
	local PlayerData, Why
	if NoSave then
		PlayerData, Why = LoadMockCopy(Key)
	else
		PlayerData = SessionData:LoadProfileAsync(Key,"ForceLoad")
	end
	if not PlayerData then
		Player:Kick(Why or "Data Failed To Load")
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
	ProfileGuard.Track(PlayerData, Player.Name .. " (" .. Key .. ")")
	PlayerData:ListenToRelease(function()
		-- (our own releases clear Sessions first; only a release from elsewhere finds it still open)
		if Sessions[Player] ~= PlayerData then return end
		Sessions[Player] = nil
		if Player.Parent and not Leaving[Player] then Player:Kick("Your data was opened somewhere else. Please rejoin.") end
	end)
end

function DataManager:Initiate()
	if NoSave then
		ReplicatedStorage:SetAttribute("TestNoSave", true) -- tests and the client can see the mode
		warn("[DataManager] TestNoSave: this Studio session will not save")
	end

	local function PlayerRemoving(Player)
		local PlayerData = Sessions[Player]
		Sessions[Player], Leaving[Player] = nil, nil
		if PlayerData then
			ProfileGuard.Final(PlayerData)
			PlayerData:Release()
		end
	end

	for I,V in pairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, V)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

-- True only in a Studio session running TestNoSave: every profile here is a mock copy that never saves.
function DataManager.IsNoSave()
	return NoSave
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
	ProfileGuard.Final(PlayerData)
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

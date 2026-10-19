-- Player profiles for the tutorial place. The SAME store as Ye's CharacterHandler.DataManager
-- (ProfileService store "PlayerData"), and the save slot the menu picked (ServerScriptService.SlotAccount;
-- slot 1 = "Data" .. UserId), so all places read and write one profile. ProfileService's session lock
-- hands the profile from place to place across teleports (released on leave / before a teleport,
-- ForceLoad on arrival).
-- Migrations: ServerScriptService.ProfileMigrations (the same file in every place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local ProfileMigrations = require(script.Parent.ProfileMigrations)
local SlotAccount = require(script.Parent.SlotAccount)
local ProfileGuard = require(script.Parent.ProfileGuard) -- keeps an open profile saveable (data-storage audit 2026-10-18)

local Store = ProfileService.GetProfileStore("PlayerData", ProfileData)

local Sessions = {}
local Leaving = {} -- [Player] = true once released for a teleport (no "opened elsewhere" kick)

local MenuData = {}

local function PlayerAdded(Player)
	-- the save slot the menu picked; nil = the account store couldn't be read (never guess slot 1)
	local Key = SlotAccount.ProfileKey(Player.UserId)
	if not Player.Parent then return end
	if not Key then
		Player:Kick("Couldn't load your save slot. Please rejoin.")
		return
	end
	local Profile = Store:LoadProfileAsync(Key, "ForceLoad")
	if not Profile then
		Player:Kick("Data failed to load. Please rejoin.")
		return
	end
	ProfileMigrations.Migrate(Profile.Data)
	Profile:Reconcile()
	if not Player.Parent then Profile:Release() return end
	Sessions[Player] = Profile
	ProfileGuard.Track(Profile, Player.Name .. " (" .. Key .. ")")
	Profile:ListenToRelease(function()
		-- (our own releases clear Sessions first; only a release from elsewhere finds it still open)
		if Sessions[Player] ~= Profile then return end
		Sessions[Player] = nil
		if Player.Parent and not Leaving[Player] then Player:Kick("Your data was opened somewhere else.") end
	end)
end

function MenuData.Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end
	Players.PlayerRemoving:Connect(function(Player)
		local Profile = Sessions[Player]
		Sessions[Player], Leaving[Player] = nil, nil
		if Profile then ProfileGuard.Final(Profile) Profile:Release() end
	end)
end

function MenuData.Get(Player)
	return Sessions[Player]
end

-- Wait (up to Timeout s) for the player's profile.
function MenuData.Wait(Player, Timeout)
	local Deadline = os.clock() + (Timeout or 15)
	while not Sessions[Player] and Player.Parent and os.clock() < Deadline do task.wait(0.1) end
	return Sessions[Player]
end

-- Release now (just before a teleport) so the next place's ForceLoad doesn't wait it out. Yields
-- until the release has saved (ProfileService "hop ready", at most 6 s).
function MenuData.Release(Player)
	local Profile = Sessions[Player]
	Leaving[Player] = true
	Sessions[Player] = nil
	if not Profile then return end
	local Ready = false
	Profile:ListenToHopReady(function() Ready = true end)
	ProfileGuard.Final(Profile)
	Profile:Release()
	local Deadline = os.clock() + 6
	while not Ready and os.clock() < Deadline do task.wait(0.1) end
end

-- A teleport that failed after Release: load the profile again so the player can carry on.
function MenuData.Reload(Player)
	Leaving[Player] = nil
	if not Sessions[Player] and Player.Parent then PlayerAdded(Player) end
	return Sessions[Player]
end

return MenuData
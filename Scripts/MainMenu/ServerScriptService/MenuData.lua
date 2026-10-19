-- Player profiles for the flow places (Menu, Tutorial). The SAME store as Ye's
-- CharacterHandler.DataManager (ProfileService store "PlayerData"), so all places read and write one
-- profile. ProfileService's session lock hands the profile from place to place across teleports
-- (released on leave / before a teleport, ForceLoad on arrival).
-- SAVE SLOTS (owner 2026-10-15): each slot is its own profile (Rensei.Slots.Key; slot 1 = the original
-- "Data" .. UserId). Nothing is loaded on join: the menu shows the slots (ViewProfileAsync, no lock),
-- and Open(Player, Slot) loads the picked one and records it in SlotAccount so the next place loads
-- the same slot.
-- Migrations: ServerScriptService.ProfileMigrations (the same file in every place).
-- A slot account that can't be read isn't cached (Account retries it), so a store hiccup never shows
-- the default 2 slots in place of the ones owned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local Slots = require(ReplicatedStorage.Modules.Data.Rensei.Slots)
local SlotAccount = require(ServerScriptService.SlotAccount)

local ProfileMigrations = require(ServerScriptService.ProfileMigrations)
local ProfileGuard = require(ServerScriptService.ProfileGuard) -- keeps an open profile saveable (data-storage audit 2026-10-18)

local Store = ProfileService.GetProfileStore("PlayerData", ProfileData)

local Sessions = {} -- [Player] = the open slot's Profile
local OpenSlot = {} -- [Player] = slot number of Sessions[Player]
local Accounts = {} -- [Player] = SlotAccount record (cached)
local Leaving = {} -- [Player] = true once released for a teleport (no "opened elsewhere" kick)
local Fetching = {} -- [Player] = true while the slot account is being read

local MenuData = {}

-- Read the slot account; cached only when the read worked.
local function Fetch(Player)
	if Fetching[Player] then return end
	Fetching[Player] = true
	local Account, Ok = SlotAccount.Get(Player.UserId)
	Fetching[Player] = nil
	if Ok and Player.Parent then Accounts[Player] = Account end
end

function MenuData.Start()
	Players.PlayerAdded:Connect(Fetch)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(Fetch, P) end
	Players.PlayerRemoving:Connect(function(Player)
		local Profile = Sessions[Player]
		Sessions[Player], OpenSlot[Player], Accounts[Player], Leaving[Player], Fetching[Player] = nil, nil, nil, nil, nil
		if Profile then ProfileGuard.Final(Profile) Profile:Release() end
	end)
end

-- The player's slot account (waits for it on join; a failed read is tried again). nil = unreadable.
function MenuData.Account(Player, Refresh)
	if Refresh then Accounts[Player] = nil end
	local Deadline = os.clock() + 15
	while not Accounts[Player] and Player.Parent and os.clock() < Deadline do
		if not Fetching[Player] then task.spawn(Fetch, Player) end
		task.wait(0.1)
	end
	return Accounts[Player]
end

-- What each owned slot holds, for the slot screen: {Slot, Created, Name, Level, Origin, Clan}.
function MenuData.Summaries(Player)
	local Account = MenuData.Account(Player)
	if not Account then return nil end
	local List = {}
	for Slot = 1, Account.Owned do
		local Data
		if OpenSlot[Player] == Slot and Sessions[Player] then
			Data = Sessions[Player].Data
		else
			local Ok, Profile = pcall(function() return Store:ViewProfileAsync(Slots.Key(Player.UserId, Slot)) end)
			Data = Ok and Profile and Profile.Data or nil
		end
		local I = Data and Data.Identity
		table.insert(List, {
			Slot = Slot,
			Created = I and I.CharacterCreated or false,
			Name = I and I.Name or "",
			Level = Data and Data.Level or 1,
			Origin = I and I.Origin or "",
			Clan = I and I.Clan or "",
		})
	end
	return List
end

-- Load a slot's profile (releasing any other open one). Returns the profile or nil, message.
function MenuData.Open(Player, Slot)
	local Account = MenuData.Account(Player)
	if not Account then return nil, "Still loading your account." end
	if type(Slot) ~= "number" or Slot < 1 or Slot > Account.Owned or Slot ~= math.floor(Slot) then return nil, "You don't own that slot." end
	if OpenSlot[Player] == Slot and Sessions[Player] then return Sessions[Player] end
	local Old = Sessions[Player]
	Sessions[Player], OpenSlot[Player] = nil, nil
	if Old then ProfileGuard.Final(Old) Old:Release() end
	if not SlotAccount.Select(Player.UserId, Slot) then return nil, "Couldn't pick that slot. Try again." end
	Account.Selected = Slot
	local Profile = Store:LoadProfileAsync(Slots.Key(Player.UserId, Slot), "ForceLoad")
	if not Profile then return nil, "That slot didn't load. Try again." end
	ProfileMigrations.Migrate(Profile.Data)
	Profile:Reconcile()
	if not Player.Parent then Profile:Release() return nil end
	Leaving[Player] = nil
	Sessions[Player], OpenSlot[Player] = Profile, Slot
	ProfileGuard.Track(Profile, Player.Name .. " (slot " .. Slot .. ")")
	Profile:ListenToRelease(function()
		-- (our own releases clear Sessions first; only a release from elsewhere finds it still open)
		if Sessions[Player] ~= Profile then return end
		Sessions[Player], OpenSlot[Player] = nil, nil
		if Player.Parent and not Leaving[Player] then Player:Kick("Your data was opened somewhere else.") end
	end)
	return Profile
end

-- Delete a slot's character: its profile is wiped (the slot itself stays owned, and empty).
-- Returns ok, message.
function MenuData.Delete(Player, Slot)
	local Account = MenuData.Account(Player)
	if not Account then return false, "Still loading your account." end
	if type(Slot) ~= "number" or Slot < 1 or Slot > Account.Owned or Slot ~= math.floor(Slot) then return false, "You don't own that slot." end
	if OpenSlot[Player] == Slot then
		local Profile = Sessions[Player]
		Sessions[Player], OpenSlot[Player] = nil, nil
		if Profile then Profile:Release() end
	end
	local Ok, Err = pcall(function() return Store:WipeProfileAsync(Slots.Key(Player.UserId, Slot)) end)
	if not Ok or Err == false then
		warn("Slot delete failed:", Err)
		return false, "Couldn't delete that slot. Try again."
	end
	return true
end

function MenuData.Get(Player)
	return Sessions[Player]
end

function MenuData.Slot(Player)
	return OpenSlot[Player]
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

-- A teleport that failed after Release: load the same slot again so the player can carry on.
function MenuData.Reload(Player)
	local Slot = OpenSlot[Player]
	Leaving[Player] = nil
	OpenSlot[Player] = nil
	if Slot and Player.Parent then MenuData.Open(Player, Slot) end
	return Sessions[Player]
end

return MenuData

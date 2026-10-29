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
-- TestNoSave (Studio only, 2026-10-28; the same switch as Ye's DataManager): set ServerStorage's TestNoSave
-- attribute to true in Edit before Play. Saves are then read with a plain GetAsync (no lock, no write) into
-- ProfileService MOCK profiles (memory only), and the account record's writes (pick, star, codes, Studio test
-- purchases) change only this server's copy. MenuServer sends its account writes through MenuData for this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local ProfileService = require(script.ProfileService)
local ProfileData = require(ReplicatedStorage.Modules.Data.ProfileData)
local Slots = require(ReplicatedStorage.Modules.Data.Rensei.Slots)
local SlotAccount = require(ServerScriptService.SlotAccount)

local ProfileMigrations = require(ServerScriptService.ProfileMigrations)
local ProfileGuard = require(ServerScriptService.ProfileGuard) -- keeps an open profile saveable (data-storage audit 2026-10-18)

local Store = ProfileService.GetProfileStore("PlayerData", ProfileData)

-- IsStudio() first, the attribute second: a live server never reads TestNoSave. Decided once, at load.
local NoSave = RunService:IsStudio() and ServerStorage:GetAttribute("TestNoSave") == true

local Sessions = {} -- [Player] = the open slot's Profile
local OpenSlot = {} -- [Player] = slot number of Sessions[Player]
local Accounts = {} -- [Player] = SlotAccount record (cached)
local Leaving = {} -- [Player] = true once released for a teleport (no "opened elsewhere" kick)
local Fetching = {} -- [Player] = true while the slot account is being read
local Seeded = {} -- TestNoSave: [Player][Slot] = true once that slot's mock exists (it's never re-copied from the real save)

local MenuData = {}

local function DeepCopy(T)
	if type(T) ~= "table" then return T end
	local C = {}
	for K, V in pairs(T) do C[K] = DeepCopy(V) end
	return C
end

-- TestNoSave: a slot's real save, read with a plain GetAsync (not ViewProfileAsync: in this ProfileService its view
-- goes through UpdateAsync, a write). Returns ok, Data (nil = an empty slot).
local function ReadReal(Key)
	local Ok, Record = pcall(function() return DataStoreService:GetDataStore("PlayerData"):GetAsync(Key) end)
	if not Ok then return false end
	-- a deleted slot ("PROFILE_WIPED") or a GlobalUpdates-only stub is an empty slot to ProfileService too
	if Record == "PROFILE_WIPED" or type(Record) ~= "table" or type(Record.Data) ~= "table" then return true, nil end
	return true, Record.Data
end

-- TestNoSave: the slot's mock profile, copied from the real save the first time it's opened this session.
-- Returns the profile, or nil and why (the session never falls back to the real store).
local function LoadMock(Player, Slot, Key)
	Seeded[Player] = Seeded[Player] or {}
	local Data
	if not Seeded[Player][Slot] then
		local Ok, Real = ReadReal(Key)
		if not Ok then return nil, "TestNoSave: couldn't read that slot. Nothing was saved." end
		Data = Real
	end
	local Mock = Store.Mock:LoadProfileAsync(Key, "ForceLoad")
	if not Mock then return nil, "TestNoSave: the test copy didn't load. Nothing was saved." end
	if not Seeded[Player][Slot] then
		if Data then Mock.Data = DeepCopy(Data) end -- (an empty slot keeps the template)
		Seeded[Player][Slot] = true
	end
	return Mock
end

-- True only in a Studio session running TestNoSave: every profile and account change here is memory only.
function MenuData.IsNoSave()
	return NoSave
end

-- Read the slot account; cached only when the read worked.
local function Fetch(Player)
	if Fetching[Player] then return end
	Fetching[Player] = true
	local Account, Ok = SlotAccount.Get(Player.UserId)
	Fetching[Player] = nil
	if Ok and Player.Parent then Accounts[Player] = Account end
end

function MenuData.Start()
	if NoSave then
		ReplicatedStorage:SetAttribute("TestNoSave", true) -- tests and the client can see the mode
		warn("[MenuData] TestNoSave: this Studio session will not save")
	end
	Players.PlayerAdded:Connect(Fetch)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(Fetch, P) end
	Players.PlayerRemoving:Connect(function(Player)
		local Profile = Sessions[Player]
		Sessions[Player], OpenSlot[Player], Accounts[Player], Leaving[Player], Fetching[Player], Seeded[Player] = nil, nil, nil, nil, nil, nil
		if Profile then ProfileGuard.Final(Profile) Profile:Release() end
	end)
end

-- The player's slot account (waits for it on join; a failed read is tried again). nil = unreadable.
-- (TestNoSave: the copy in memory is the account, so Refresh keeps it.)
function MenuData.Account(Player, Refresh)
	if Refresh and not NoSave then Accounts[Player] = nil end
	local Deadline = os.clock() + 15
	while not Accounts[Player] and Player.Parent and os.clock() < Deadline do
		if not Fetching[Player] then task.spawn(Fetch, Player) end
		task.wait(0.1)
	end
	return Accounts[Player]
end

-- What each owned slot holds, for the slot screen: {Slot, Created, Name, Level, Origin, Clan, Gender, Appearance, Region}.
function MenuData.Summaries(Player)
	local Account = MenuData.Account(Player)
	if not Account then return nil end
	local List = {}
	for Slot = 1, Account.Owned do
		local Data
		if OpenSlot[Player] == Slot and Sessions[Player] then
			Data = Sessions[Player].Data
		elseif NoSave then
			local Key = Slots.Key(Player.UserId, Slot)
			if Seeded[Player] and Seeded[Player][Slot] then
				local Ok, Profile = pcall(function() return Store.Mock:ViewProfileAsync(Key) end)
				Data = Ok and Profile and Profile.Data or nil
			else
				local _, Real = ReadReal(Key)
				Data = Real
			end
		else
			local Ok, Profile = pcall(function() return Store:ViewProfileAsync(Slots.Key(Player.UserId, Slot)) end)
			Data = Ok and Profile and Profile.Data or nil
		end
		local I = Data and Data.Identity
		local Created = I and I.CharacterCreated or false
		table.insert(List, {
			Slot = Slot,
			Created = Created,
			Name = I and I.Name or "",
			Level = Data and Data.Level or 1,
			Origin = I and I.Origin or "",
			Clan = I and I.Clan or "",
			Gender = I and I.Gender or "",
			-- the painted menu dresses each slot's alcove figure and card bust in it (Customization.Clean's shape)
			Appearance = Created and type(I.Appearance) == "table" and DeepCopy(I.Appearance) or nil,
			Region = Data and type(Data.Travel) == "table" and Data.Travel.Region or "", -- where they were last
		})
	end
	return List
end

-- Load a slot's profile (releasing any other open one). Returns the profile or nil, message.
function MenuData.Open(Player, Slot)
	local Account = MenuData.Account(Player)
	if not Account then return nil, "Still loading your account." end
	if type(Slot) ~= "number" or Slot < 1 or Slot > Account.Owned or Slot ~= math.floor(Slot) then return nil, "You don't own that slot." end
	-- (menu audit 2026-10-29) released for a teleport: picking another slot now would point the account at a slot
	-- other than the one the next place was sent (Reload clears Leaving before it opens the slot again)
	if Leaving[Player] then return nil, "You're on your way. One moment..." end
	if OpenSlot[Player] == Slot and Sessions[Player] then return Sessions[Player] end
	local Old = Sessions[Player]
	Sessions[Player], OpenSlot[Player] = nil, nil
	if Old then ProfileGuard.Final(Old) Old:Release() end
	if not NoSave and not SlotAccount.Select(Player.UserId, Slot) then return nil, "Couldn't pick that slot. Try again." end
	Account.Selected = Slot
	local Profile, Why
	if NoSave then
		Profile, Why = LoadMock(Player, Slot, Slots.Key(Player.UserId, Slot))
	else
		Profile = Store:LoadProfileAsync(Slots.Key(Player.UserId, Slot), "ForceLoad")
	end
	if not Profile then return nil, Why or "That slot didn't load. Try again." end
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
	if Leaving[Player] then return false, "You're on your way. One moment..." end -- (as in Open)
	if OpenSlot[Player] == Slot then
		local Profile = Sessions[Player]
		Sessions[Player], OpenSlot[Player] = nil, nil
		if Profile then Profile:Release() end
	end
	local Ok, Err
	if NoSave then
		-- only the mock is wiped (and the slot then stays empty for the rest of the test)
		Ok, Err = pcall(function() return Store.Mock:WipeProfileAsync(Slots.Key(Player.UserId, Slot)) end)
		Seeded[Player] = Seeded[Player] or {}
		Seeded[Player][Slot] = true
	else
		Ok, Err = pcall(function() return Store:WipeProfileAsync(Slots.Key(Player.UserId, Slot)) end)
	end
	if not Ok or Err == false then
		warn("Slot delete failed:", Err)
		return false, "Couldn't delete that slot. Try again."
	end
	return true
end

-- The account record's writes, for MenuServer (SlotAccount's own API, same results). TestNoSave: they change only
-- this server's copy of the account, which MenuData.Account then keeps.
function MenuData.SetFavorite(Player, Slot)
	if not NoSave then return SlotAccount.SetFavorite(Player.UserId, Slot) end
	local A = MenuData.Account(Player)
	return A ~= nil and type(Slot) == "number" and Slot >= 0 and Slot <= A.Owned
end

function MenuData.Redeem(Player, Code)
	if not NoSave then return SlotAccount.Redeem(Player.UserId, Code) end
	local A = MenuData.Account(Player)
	if not A then return nil end
	if A.Codes[Code] then return "Used" end
	A.Codes[Code] = os.time()
	return "Ok"
end

function MenuData.Grant(UserId, PurchaseId)
	if not NoSave then return SlotAccount.Grant(UserId, PurchaseId) end
	local Player = Players:GetPlayerByUserId(UserId)
	local A = Player and MenuData.Account(Player)
	if not A then return nil end
	if table.find(A.Receipts, PurchaseId) then return "Already" end
	if A.Owned >= Slots.Max then return "Full" end
	A.Owned += 1
	table.insert(A.Receipts, PurchaseId)
	return "Granted"
end

function MenuData.GrantPlus(UserId, PurchaseId)
	if not NoSave then return SlotAccount.GrantPlus(UserId, PurchaseId) end
	local Player = Players:GetPlayerByUserId(UserId)
	local A = Player and MenuData.Account(Player)
	if not A then return nil end
	if table.find(A.Receipts, PurchaseId) then return "Already" end
	A.Plus = true
	table.insert(A.Receipts, PurchaseId)
	return "Granted"
end

-- A reroll pack's claim on a save slot (SlotAccount.ClaimReroll, same results; TestNoSave: this server's copy).
function MenuData.ClaimReroll(Player, PurchaseId, Slot, From)
	if not NoSave then return SlotAccount.ClaimReroll(Player.UserId, PurchaseId, Slot, From) end
	local A = MenuData.Account(Player)
	if not A then return nil end
	local Claim = SlotAccount.RerollClaim(A, PurchaseId)
	if Claim and not (From and Claim.Slot == From) then return Claim.Slot end
	if Claim then Claim.Slot = Slot else table.insert(A.Receipts, {Reroll = PurchaseId, Slot = Slot}) end
	return Slot
end

-- Whether a slot's last save holds a reroll purchase (its profile's RerollPurchases MetaTag), for a purchase claimed
-- by a slot that isn't open here: true / false, or nil while that slot is still open somewhere (its save isn't final)
-- or can't be read.
function MenuData.RerollSaved(Player, Slot, PurchaseId)
	local Ok, View = pcall(function() return (NoSave and Store.Mock or Store):ViewProfileAsync(Slots.Key(Player.UserId, Slot)) end)
	if not Ok then return nil end
	local Meta = View and View.MetaData
	if type(Meta) ~= "table" then return false end -- (an empty or deleted slot)
	if Meta.ActiveSession ~= nil then return nil end
	local Ids = type(Meta.MetaTags) == "table" and Meta.MetaTags.RerollPurchases
	return type(Ids) == "table" and table.find(Ids, PurchaseId) ~= nil
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

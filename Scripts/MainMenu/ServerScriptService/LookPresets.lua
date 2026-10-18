-- Saved looks (Creator Plus, 2026-10-18): CreatorPlus.LookSlots looks per account, loadable into any new
-- character. One DataStore record per player ("RenseiLooks", key "L" .. UserId), written only by the
-- menu server. Every look is cleaned by Customization.Clean before it is stored.
-- Studio keeps them in memory only, so testing never writes the live store.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Customization = require(ReplicatedStorage.Modules.Data.Rensei.Customization)
local CreatorPlus = require(ReplicatedStorage.Modules.Data.Rensei.CreatorPlus)

local Store = not RunService:IsStudio() and DataStoreService:GetDataStore("RenseiLooks") or nil
local Memory = {} -- Studio: [UserId] = looks
local Cache = {} -- [UserId] = looks (as last read / written)

local LookPresets = {}

-- One stored look, or nil if it isn't one.
local function CleanOne(L)
	if type(L) ~= "table" then return nil end
	local Nation = type(L.Origin) == "string" and Customization.Nations[L.Origin] and L.Origin
	local Gender = type(L.Gender) == "string" and table.find(Customization.Genders, L.Gender) and L.Gender
	if not Nation or not Gender then return nil end
	local Look = Customization.Clean(Nation, L.Appearance)
	Look.Body = Gender
	return {Origin = Nation, Gender = Gender, Appearance = Look, Saved = tonumber(L.Saved) or 0}
end

local function CleanAll(Raw)
	local Out = {}
	for I = 1, CreatorPlus.LookSlots do
		Out[I] = type(Raw) == "table" and CleanOne(Raw[I]) or false
	end
	return Out
end

local function Retry(F)
	for Try = 1, 3 do
		local Ok, A = pcall(F)
		if Ok then return true, A end
		if Try == 3 then warn("LookPresets:", A) return false end
		task.wait(Try)
	end
end

-- The player's saved looks ({[1..LookSlots] = look | false}), or nil if the store can't be read.
function LookPresets.Get(Player)
	local Id = Player.UserId
	if Cache[Id] then return Cache[Id] end
	if not Store then
		Cache[Id] = CleanAll(Memory[Id])
		return Cache[Id]
	end
	local Ok, Raw = Retry(function() return Store:GetAsync("L" .. Id) end)
	if not Ok then return nil end
	Cache[Id] = CleanAll(Raw)
	return Cache[Id]
end

-- Save Look ({Origin, Gender, Appearance}) into slot Index, or clear it (Look = nil). Returns ok, message.
function LookPresets.Set(Player, Index, Look)
	if type(Index) ~= "number" or Index ~= math.floor(Index) or Index < 1 or Index > CreatorPlus.LookSlots then
		return false, "No such look slot."
	end
	local Clean = false
	if Look ~= nil then
		Clean = CleanOne(Look)
		if not Clean then return false, "That look isn't complete." end
		Clean.Saved = os.time()
	end
	local Id = Player.UserId
	if not Store then
		Memory[Id] = CleanAll(Memory[Id])
		Memory[Id][Index] = Clean
		Cache[Id] = CleanAll(Memory[Id])
		return true
	end
	local Result
	local Ok = Retry(function()
		Store:UpdateAsync("L" .. Id, function(Raw)
			local All = CleanAll(Raw)
			All[Index] = Clean
			Result = All
			return All
		end)
	end)
	if not Ok then return false, "Couldn't save that look. Try again." end
	Cache[Id] = Result
	return true
end

Players.PlayerRemoving:Connect(function(P) Cache[P.UserId] = nil end)

return LookPresets

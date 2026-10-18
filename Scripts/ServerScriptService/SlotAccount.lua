-- A player's save-slot account: how many slots they own and which one they're playing. One small
-- DataStore record per player ("RenseiAccounts", key "A" .. UserId), written only by servers, so a
-- place loads the slot the menu picked (Slots.Key(UserId, Account.Selected)).
-- KEEP THIS FILE THE SAME IN EVERY PLACE.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Slots = require(ReplicatedStorage.Modules.Data.Rensei.Slots)

local Store = DataStoreService:GetDataStore("RenseiAccounts")

-- Reads skip the server's 4 s GetAsync cache: the slot was usually just picked on another server.
local Fresh = Instance.new("DataStoreGetOptions")
Fresh.UseCache = false

local SlotAccount = {}

local function Clean(A)
	A = type(A) == "table" and A or {}
	return {
		Owned = math.clamp(tonumber(A.Owned) or Slots.Free, Slots.Free, Slots.Max),
		Selected = tonumber(A.Selected) or 1,
		Favorite = tonumber(A.Favorite) or 0, -- starred slot, listed first on the slot screen; 0 = none
		Receipts = type(A.Receipts) == "table" and A.Receipts or {}, -- recent purchase ids (no double grant)
		Codes = type(A.Codes) == "table" and A.Codes or {}, -- [CODE] = os.time() it was used (ClanCodes)
		Plus = A.Plus == true, -- owns Creator Plus (the Developer Product, bought once per account)
	}
end

local function Retry(F)
	for Try = 1, 4 do
		local Ok, A, B = pcall(F)
		if Ok then return true, A, B end
		if Try == 4 then warn("SlotAccount:", A) return false end
		task.wait(Try)
	end
end

-- The account (never nil: defaults if the store can't be read; Ok = false then).
function SlotAccount.Get(UserId)
	local Ok, Raw = Retry(function() return Store:GetAsync("A" .. UserId, Fresh) end)
	local A = Clean(Raw)
	A.Selected = math.clamp(A.Selected, 1, A.Owned)
	return A, Ok
end

-- The profile key the player should load in this place, or nil if the account couldn't be read
-- (the caller kicks: loading slot 1 by default would put the player on the wrong save).
function SlotAccount.ProfileKey(UserId)
	local A, Ok = SlotAccount.Get(UserId)
	if not Ok then return nil end
	return Slots.Key(UserId, A.Selected), A.Selected
end

-- Pick a slot (must be owned). Returns ok.
function SlotAccount.Select(UserId, Slot)
	if type(Slot) ~= "number" or Slot ~= math.floor(Slot) or Slot < 1 or Slot > Slots.Max then return false end
	local Allowed = false
	local Ok = Retry(function()
		Store:UpdateAsync("A" .. UserId, function(Raw)
			local A = Clean(Raw)
			Allowed = Slot <= A.Owned
			if not Allowed then return nil end
			A.Selected = Slot
			return A
		end)
	end)
	return Ok and Allowed
end

-- Star a slot (it's listed first), or 0 to clear. Returns ok.
function SlotAccount.SetFavorite(UserId, Slot)
	if type(Slot) ~= "number" or Slot ~= math.floor(Slot) or Slot < 0 or Slot > Slots.Max then return false end
	local Allowed = false
	local Ok = Retry(function()
		Store:UpdateAsync("A" .. UserId, function(Raw)
			local A = Clean(Raw)
			Allowed = Slot <= A.Owned
			if not Allowed then return nil end
			A.Favorite = Slot
			return A
		end)
	end)
	return Ok and Allowed
end

-- Mark a code as used by this account. Returns "Ok" | "Used" | nil (store failed).
function SlotAccount.Redeem(UserId, Code)
	local Result
	local Ok = Retry(function()
		Store:UpdateAsync("A" .. UserId, function(Raw)
			local A = Clean(Raw)
			if A.Codes[Code] then Result = "Used" return nil end
			A.Codes[Code] = os.time()
			Result = "Ok"
			return A
		end)
	end)
	return Ok and Result or nil
end

-- A bought slot (ProcessReceipt). Returns "Granted" | "Already" | "Full" | nil (store failed: retry later).
function SlotAccount.Grant(UserId, PurchaseId)
	local Result
	local Ok = Retry(function()
		Store:UpdateAsync("A" .. UserId, function(Raw)
			local A = Clean(Raw)
			if table.find(A.Receipts, PurchaseId) then Result = "Already" return nil end
			if A.Owned >= Slots.Max then Result = "Full" return nil end
			A.Owned += 1
			table.insert(A.Receipts, PurchaseId)
			while #A.Receipts > 20 do table.remove(A.Receipts, 1) end
			Result = "Granted"
			return A
		end)
	end)
	return Ok and Result or nil
end

-- Creator Plus bought (ProcessReceipt). Returns "Granted" | "Already" | nil (store failed: retry later).
function SlotAccount.GrantPlus(UserId, PurchaseId)
	local Result
	local Ok = Retry(function()
		Store:UpdateAsync("A" .. UserId, function(Raw)
			local A = Clean(Raw)
			if table.find(A.Receipts, PurchaseId) then Result = "Already" return nil end
			A.Plus = true
			table.insert(A.Receipts, PurchaseId)
			while #A.Receipts > 20 do table.remove(A.Receipts, 1) end
			Result = "Granted"
			return A
		end)
	end)
	return Ok and Result or nil
end

return SlotAccount

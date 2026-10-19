-- ItemService: using hotbar items. A held consumable is used by clicking (Tool.Activated, hooked
-- by Requests.HoldItem). Healing items (ItemData Consumable field Heal) heal a little at a time:
-- Heal = fraction of max health over HealTime seconds, in ticks of HEAL_EVERY. Eating more adds to
-- what is still to come (the rate stays the same, it just lasts longer). Paused while knocked.
-- Each use takes one off the stack; an empty stack leaves the inventory (hotbar / equipped-weapon
-- indices are shifted to match).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)

local HEAL_EVERY = 0.5 -- seconds between heal ticks (PROPOSAL)
-- bounds on what a save can hold (data-storage audit 2026-10-18; PROPOSALS): a repeatable reward or an admin
-- command used to grow the inventory without limit
local MAX_ENTRIES = 60 -- inventory entries (each non-stacking item is one)
local MAX_STACK = 999 -- a consumable stack
local MAX_GIVE = 25 -- items one Give can add

local function Full(Player)
	pcall(function() require(ServerScriptService.UIService).Notify(Player, "Toast", {Text = "Your bag is full."}) end)
	return false
end
local USE_COOLDOWN = 1 -- seconds between uses (PROPOSAL)

local ItemService = {}

-- Remove inventory entry Index and keep every saved reference to later entries pointing right.
function ItemService.RemoveIndex(PlayerData, Index)
	table.remove(PlayerData.Inventory, Index)
	for Slot, V in pairs(PlayerData.Hotbar) do
		if V == Index then PlayerData.Hotbar[Slot] = ""
		elseif type(V) == "number" and V > Index then PlayerData.Hotbar[Slot] = V - 1 end
	end
	local W = PlayerData.EquippedWeapon
	if W == Index then PlayerData.EquippedWeapon = ""
	elseif type(W) == "number" and W > Index then PlayerData.EquippedWeapon = W - 1 end
end

-- Add an item to the player's inventory (quest rewards, admin). Consumables stack onto an
-- existing entry; anything else is a new entry with its own ItemID. Returns true on success.
function ItemService.Give(Player, Name, Amount)
	Amount = tonumber(Amount) or 1
	if Amount ~= Amount then Amount = 1 end
	Amount = math.clamp(math.floor(Amount), 1, MAX_GIVE)
	local Info = ItemData[Name]
	local Profile = DataManager:GetProfile(Player)
	if not Info or not Profile then return false end
	local Inventory = Profile.Data.Inventory
	if Info.Type == "Consumable" then
		for _, Item in ipairs(Inventory) do
			if Item.ItemName == Name then
				if (Item.Amount or 1) >= MAX_STACK then return Full(Player) end
				Item.Amount = math.min(MAX_STACK, (Item.Amount or 1) + Amount)
				DataManager:SendData(Player)
				return true
			end
		end
		if #Inventory >= MAX_ENTRIES then return Full(Player) end
		table.insert(Inventory, {ItemName = Name, ItemID = game:GetService("HttpService"):GenerateGUID(false):sub(1, 8), Amount = Amount})
	else
		if #Inventory + Amount > MAX_ENTRIES then return Full(Player) end -- all or nothing (a reward is never half-paid)
		for _ = 1, Amount do
			table.insert(Inventory, {ItemName = Name, ItemID = game:GetService("HttpService"):GenerateGUID(false):sub(1, 8)})
		end
	end
	DataManager:SendData(Player)
	return true
end

-- ===== Healing over time =====
local Pools = {} -- [Humanoid] = {Left = HP still to heal, Rate = HP per second}

local function AddHeal(Humanoid, Amount, Duration)
	local P = Pools[Humanoid]
	if P then
		P.Left += Amount
		P.Rate = math.max(P.Rate, Amount / Duration)
	else
		Pools[Humanoid] = {Left = Amount, Rate = Amount / Duration}
	end
end

local Elapsed = 0
RunService.Heartbeat:Connect(function(Dt)
	Elapsed += Dt
	if Elapsed < HEAL_EVERY then return end
	local Step = Elapsed
	Elapsed = 0
	for Humanoid, P in pairs(Pools) do
		local Character = Humanoid.Parent
		if not Character or not Character.Parent or Humanoid.Health <= 0 then
			Pools[Humanoid] = nil
		elseif not Character:GetAttribute("Knocked") then
			local Amount = math.min(P.Left, P.Rate * Step)
			P.Left -= Amount
			Humanoid.Health = math.min(Humanoid.MaxHealth, Humanoid.Health + Amount)
			if P.Left <= 1e-3 or Humanoid.Health >= Humanoid.MaxHealth then Pools[Humanoid] = nil end
		end
	end
end)

-- ===== Use =====
function ItemService.Use(Player, Tool)
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 or Tool.Parent ~= Character then return end
	if Character:GetAttribute("Knocked") or Character:GetAttribute("CombatMode") then return end
	local Info = ItemData[Tool.Name]
	-- transmutation chalk: starts a circle (RitualService checks everything; the chalk is spent per attempt there)
	if Info and Info.Ritual then
		require(game:GetService("ServerScriptService").RitualService).BeginCircle(Player)
		return
	end
	if not Info or Info.Type ~= "Consumable" or not Info.Heal then return end
	local Now = workspace:GetServerTimeNow()
	if (Character:GetAttribute("ItemUseReadyAt") or 0) > Now then return end
	if Humanoid.Health >= Humanoid.MaxHealth then return end -- nothing to heal: keep the item

	local Profile = DataManager:GetProfile(Player)
	if not Profile then return end
	local PlayerData = Profile.Data
	local Index
	for I, Item in ipairs(PlayerData.Inventory) do
		if Item.ItemName == Tool.Name and (Item.Amount or 1) > 0 then Index = I break end
	end
	if not Index then Tool:Destroy() return end

	Character:SetAttribute("ItemUseReadyAt", Now + USE_COOLDOWN)
	local Item = PlayerData.Inventory[Index]
	local Left = (Item.Amount or 1) - 1
	if Left > 0 then
		Item.Amount = Left
	else
		ItemService.RemoveIndex(PlayerData, Index)
		Tool:Destroy() -- the last one
	end
	AddHeal(Humanoid, Humanoid.MaxHealth * Info.Heal, Info.HealTime or 6)
	DataManager:SendData(Player)
end

return ItemService

-- LoadoutService: the equipped weapon. Weapons never go on the hotbar; they are equipped from the
-- inventory (InventoryUI -> Requests.Equip -> here). The choice is saved (profile EquippedWeapon =
-- inventory index, "" = fists) and the weapon's Tool is given again on every spawn. WeaponManager
-- then attaches it (holstered outside Combat Mode, drawn in it).
--
-- Hotbar items (consumables) are held through Requests.HoldItem and live beside the weapon Tool;
-- this module only ever touches the weapon Tool.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)

local LoadoutService = {}

function LoadoutService.IsWeapon(ItemName)
	local Info = ItemName and ItemData[ItemName]
	return Info ~= nil and Info.Type == "Weapon"
end

local function WeaponTools(Character)
	local Out = {}
	for _, T in ipairs(Character:GetChildren()) do
		if T:IsA("Tool") and LoadoutService.IsWeapon(T.Name) then table.insert(Out, T) end
	end
	return Out
end

-- The saved weapon (inventory index) if it is still a weapon in the inventory, else nil.
local function SavedWeapon(PlayerData)
	local Index = PlayerData.EquippedWeapon
	local Item = type(Index) == "number" and PlayerData.Inventory[Index]
	return Item and LoadoutService.IsWeapon(Item.ItemName) and Index or nil, Item
end

-- Make the character hold exactly the saved weapon (or none).
local function Apply(Player, PlayerData)
	local Character = Player.Character
	if not Character then return end
	local Index, Item = SavedWeapon(PlayerData)
	local Want = Index and Item.ItemName
	for _, T in ipairs(WeaponTools(Character)) do
		if T.Name ~= Want then T:Destroy() else Want = nil end -- already held
	end
	if Want then
		local Source = ReplicatedStorage.Assets.Items.Weapon:FindFirstChild(Want)
		if Source then Source:Clone().Parent = Character end
	end
end

-- Old saves held weapons on the hotbar: take them off it, and keep the first one as the
-- equipped weapon if none is set.
local function Migrate(PlayerData)
	if PlayerData.EquippedWeapon == nil then PlayerData.EquippedWeapon = "" end
	for Slot, Index in pairs(PlayerData.Hotbar) do
		local Item = type(Index) == "number" and PlayerData.Inventory[Index]
		if Item and LoadoutService.IsWeapon(Item.ItemName) then
			PlayerData.Hotbar[Slot] = ""
			if not SavedWeapon(PlayerData) then PlayerData.EquippedWeapon = Index end
		end
	end
	if not SavedWeapon(PlayerData) then PlayerData.EquippedWeapon = "" end
end

-- Every spawn (CharacterHandler): migrate, then give the saved weapon.
function LoadoutService.Restore(Player)
	local Profile = DataManager:GetProfile(Player)
	if not Profile then return end
	Migrate(Profile.Data)
	Apply(Player, Profile.Data)
	-- the saved weapon style (Rensei.Styles), and keep it matching the weapon from here on
	require(game:GetService("ServerScriptService").StyleService).Apply(Player)
end

-- Inventory click on a weapon: equip it, or unequip it if it is the equipped one. Not mid-attack.
function LoadoutService.Toggle(Player, ItemIndex)
	local Profile = DataManager:GetProfile(Player)
	local Character = Player.Character
	if not Profile or not Character or type(ItemIndex) ~= "number" or ItemIndex % 1 ~= 0 then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	if Character:GetAttribute("CombatState") or Character:GetAttribute("Knocked") then return end
	local PlayerData = Profile.Data
	local Item = PlayerData.Inventory[ItemIndex]
	if not Item or not LoadoutService.IsWeapon(Item.ItemName) then return end
	PlayerData.EquippedWeapon = PlayerData.EquippedWeapon == ItemIndex and "" or ItemIndex
	Apply(Player, PlayerData)
	DataManager:SendData(Player)
end

return LoadoutService

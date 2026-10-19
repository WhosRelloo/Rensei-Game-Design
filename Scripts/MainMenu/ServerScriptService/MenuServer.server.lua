-- Rensei main menu + character creation (place "Character Customization").
-- Flow (owner 2026-10-14): Main Menu -> Save slot -> Customize -> Tutorial -> cutscene -> Main game.
-- The client (StarterPlayerScripts.MenuClient) only sends choices; this script validates them
-- against Modules.Data.Rensei.Customization / Clans, saves Identity once, and teleports.
-- MenuRemote (RemoteFunction) calls:
--   "Slots"           -> {Owned, Max, Price, CanBuy, Favorite, List = {{Slot, Created, Name, Level, Origin, Clan}}}
--   "Favorite", Slot  -> ok   (stars a slot so it's listed first; the starred slot again = unstar)
--   "Delete", Slot    -> ok, message   (wipes that slot's character; the slot stays owned)
--   "Open", Slot      -> ok, message, State   (loads that save slot; State as below)
--   "State"           -> {Slot, Next = "Customize"|"Tutorial"|"Main", Identity = {...}} for the open slot
--   "Hair", HairId    -> ok, message   (loads a catalog hair into ReplicatedStorage.HairCache for the preview)
--   "RollClan"        -> ok, message, Identity  (the free roll, then paid rerolls; result saved at once)
--   "Redeem", Code    -> ok, message, Identity  (a ClanCodes code: rerolls for the open slot, once per account)
--   "Create", Choice  -> ok, message   (Choice: Origin, FirstName, Gender, Weapon,
--                                       Appearance = {Skin, Hair, HairIds, HairColor, Eyes, Brows, Mouth, Outfit})
--   "Play"            -> ok, message   (teleports to the next place in the flow)
--   "Plus"            -> {Owned, PassId, Looks}   (Creator Plus: owned? and the saved looks if so)
--   "SaveLook", {Index, Look = {Origin, Gender, Appearance}} -> ok, message, Looks   (Creator Plus)
--   "ClearLook", Index -> ok, message, Looks   (Creator Plus)
-- The surname is the rolled clan's (owner 2026-10-15); no alchemy path is picked here (Affinity "").
-- Purchases (ProcessReceipt below): a save slot (Slots.ProductId), clan reroll packs (Clans.RerollPacks).
-- Creator Plus: a custom skin colour and saved looks (2026-10-18). Sold as a Developer Product
-- (CreatorPlus.ProductId, bought once, recorded on the account) or a Game Pass (CreatorPlus.PassId).
-- The starter outfit is the nation's and the body follows the gender (owner 2026-10-15).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Customization = require(ReplicatedStorage.Modules.Data.Rensei.Customization)
local Clans = require(ReplicatedStorage.Modules.Data.Rensei.Clans)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local Slots = require(ReplicatedStorage.Modules.Data.Rensei.Slots)
local AppearanceService = require(ReplicatedStorage.Modules.AppearanceService)
local MenuData = require(script.Parent.MenuData)
local SlotAccount = require(script.Parent.SlotAccount)
local ClanCodes = require(script.Parent.ClanCodes)
local FlowTeleport = require(script.Parent.FlowTeleport)
local LookPresets = require(script.Parent.LookPresets)
local CreatorPlus = require(ReplicatedStorage.Modules.Data.Rensei.CreatorPlus)

Players.CharacterAutoLoads = false -- the menu has no avatar; the client shows a preview rig
MenuData.Start()

-- The place streams (StreamingEnabled) and nobody has a character, so stream the scenery around the
-- dais to each player: the menu camera's background ("Map thing") would never load otherwise.
local Dais = workspace:WaitForChild("MenuStage"):WaitForChild("Dais")
local function Focus(Player) Player.ReplicationFocus = Dais end
Players.PlayerAdded:Connect(Focus)
for _, P in ipairs(Players:GetPlayers()) do Focus(P) end

local Busy = {} -- [Player] = true while a call that writes is running

-- Creator Plus ownership (cached per player; a purchase in this server sets it at once)
local PlusOwned = {}
local function OwnsPlus(Player)
	if CreatorPlus.PassId == 0 and CreatorPlus.ProductId == 0 then return CreatorPlus.StudioOwns and RunService:IsStudio() end
	-- the Developer Product: a flag on the account record (not cached here; MenuData caches the account)
	if CreatorPlus.ProductId ~= 0 then
		local Account = MenuData.Account(Player)
		if Account and Account.Plus then return true end
	end
	if CreatorPlus.PassId == 0 then return false end
	if PlusOwned[Player] ~= nil then return PlusOwned[Player] end
	local Ok, Owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, CreatorPlus.PassId) end)
	if not Ok then return false end -- (not cached: asked again next time)
	PlusOwned[Player] = Owns
	return Owns
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, PassId, Bought)
	if Bought and PassId == CreatorPlus.PassId and CreatorPlus.PassId ~= 0 then PlusOwned[Player] = true end
end)

local function PlusState(Player)
	local Owned = OwnsPlus(Player)
	return {Owned = Owned, PassId = CreatorPlus.PassId, ProductId = CreatorPlus.ProductId, Looks = Owned and LookPresets.Get(Player) or nil}
end

local function SetLook(Player, Index, Look)
	if not OwnsPlus(Player) then return false, "Saved looks are part of Creator Plus." end
	local Ok, Why = LookPresets.Set(Player, Index, Look)
	return Ok, Ok and (Look and "Look saved." or "Look cleared.") or Why, LookPresets.Get(Player)
end

local function Filtered(Player, Text)
	local Ok, Result = pcall(function()
		return TextService:FilterStringAsync(Text, Player.UserId, Enum.TextFilterContext.PublicChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	if not Ok then return false, "Couldn't check that name. Try again, or pick one from the list." end
	if Result ~= Text then return false, "That name isn't allowed." end
	return true
end

local function Clean(S)
	return type(S) == "string" and (S:gsub("^%s+", ""):gsub("%s+$", "")) or ""
end

local function Summary(Data)
	local I = Data.Identity
	return {
		CharacterCreated = I.CharacterCreated, Name = I.Name, FirstName = I.FirstName, LastName = I.LastName,
		Gender = I.Gender, Origin = I.Origin, Affinity = I.Affinity, Weapon = I.Weapon,
		Clan = I.Clan, FreeRoll = not I.FreeClanRollUsed, PaidRolls = I.PaidClanRolls or 0,
		Pity = I.ClanPity or 0,
		Appearance = I.CharacterCreated and Customization.Clean(I.Origin, I.Appearance) or nil,
		Level = Data.Level,
	}
end

local function State(Player)
	local Profile = MenuData.Get(Player)
	if not Profile then return nil end
	return {Slot = MenuData.Slot(Player), Next = Places.NextFor(Profile.Data), Identity = Summary(Profile.Data)}
end

local function SlotList(Player)
	local Account = MenuData.Account(Player)
	local List = MenuData.Summaries(Player)
	if not Account or not List then return nil end
	return {Owned = Account.Owned, Max = Slots.Max, Price = Slots.Price, CanBuy = Slots.ProductId ~= 0,
		Favorite = Account.Favorite or 0, List = List}
end

local function RollClan(Player)
	local Profile = MenuData.Get(Player)
	if not Profile then return false, "Pick a save slot first." end
	local I = Profile.Data.Identity
	if I.CharacterCreated then return false, "Clan rerolls happen in game." end
	if not Clans.RollingEnabled then return false, "Clans aren't open yet." end
	if I.FreeClanRollUsed then
		if (I.PaidClanRolls or 0) <= 0 then return false, "No clan rolls left." end
		I.PaidClanRolls -= 1
	else
		I.FreeClanRollUsed = true
	end
	I.Clan = Clans.Roll(I)
	return true, nil, Summary(Profile.Data)
end

local function Redeem(Player, Code)
	local Profile = MenuData.Get(Player)
	if not Profile then return false, "Pick a save slot first." end
	Code = type(Code) == "string" and Code:gsub("%s", ""):upper() or ""
	local Def = ClanCodes[Code]
	if Code == "" or not Def or (Def.StudioOnly and not RunService:IsStudio()) then return false, "That code doesn't exist." end
	if Def.Expires and os.time() > Def.Expires then return false, "That code has expired." end
	local Result = SlotAccount.Redeem(Player.UserId, Code)
	if Result == "Used" then return false, "You've already used that code." end
	if Result ~= "Ok" then return false, "Couldn't check that code. Try again." end
	local I = Profile.Data.Identity
	I.PaidClanRolls = (I.PaidClanRolls or 0) + Def.Rolls
	return true, ("+%d clan reroll%s."):format(Def.Rolls, Def.Rolls == 1 and "" or "s"), Summary(Profile.Data)
end

local function Create(Player, Choice)
	local Profile = MenuData.Get(Player)
	if not Profile then return false, "Pick a save slot first." end
	if type(Choice) ~= "table" then return false, "Something went wrong." end
	local Data = Profile.Data
	local Identity = Data.Identity
	if Identity.CharacterCreated then return false, "This character already exists." end

	local Nation = type(Choice.Origin) == "string" and Customization.Nations[Choice.Origin] and Choice.Origin
	if not Nation then return false, "Pick a nation." end
	local Gender = type(Choice.Gender) == "string" and table.find(Customization.Genders, Choice.Gender) and Choice.Gender
	if not Gender then return false, "Pick a gender." end
	local Weapon = type(Choice.Weapon) == "string" and table.find(Customization.StartWeapons, Choice.Weapon) and Choice.Weapon
	if not Weapon then return false, "Pick a starting weapon." end
	local Clan = Clans.Roster[Identity.Clan]
	if not Clan then return false, "Roll your clan first." end

	local First = Clean(Choice.FirstName)
	if not Customization.NameShapeOk(First) then return false, "First names are 2-16 letters." end
	if not table.find(Customization.Names[Nation] or {}, First) then
		local Ok, Why = Filtered(Player, First)
		if not Ok then return false, Why end
	end
	local Look = Customization.Clean(Nation, Choice.Appearance)
	Look.Body = Gender
	if Customization.IsCustomSkin(Look) and not OwnsPlus(Player) then
		return false, "Custom skin colours are part of Creator Plus. Pick a skin swatch instead."
	end
	Look.Outfit = Customization.OutfitFor(Nation)
	for _, Id in ipairs(Look.HairIds) do
		if not AppearanceService.LoadHair(Id) then return false, "Hair ID " .. Id .. " didn't load. Clear it or try another." end
	end
	if MenuData.Get(Player) ~= Profile or Identity.CharacterCreated then return false, "Try again." end -- (the filter / hair load yield)

	Identity.Origin = Nation
	Identity.FirstName = First
	Identity.LastName = Clan.Surname
	Identity.Name = Customization.FullName(First, Clan.Surname)
	Identity.Gender = Gender
	Identity.Affinity = ""
	Identity.Weapon = Weapon
	Identity.Appearance = Look
	Identity.CharacterCreated = true

	-- starting weapon: into the inventory (unless already owned) and equipped (Ye's LoadoutService
	-- gives the Tool on arrival)
	if Weapon ~= "" then
		local Index
		for I, Item in ipairs(Data.Inventory) do
			if Item.ItemName == Weapon then Index = I break end
		end
		if not Index then
			table.insert(Data.Inventory, {ItemName = Weapon, ItemID = HttpService:GenerateGUID(false):sub(1, 8)})
			Index = #Data.Inventory
		end
		Data.EquippedWeapon = Index
	end
	return true
end

local function Play(Player)
	local Profile = MenuData.Get(Player)
	if not Profile then return false, "Pick a save slot first." end
	local Next = Places.NextFor(Profile.Data)
	if Next == "Customize" then return false, "Create your character first." end
	local PlaceId = Places[Next]
	if RunService:IsStudio() then
		return true, "Studio can't teleport. Live, this goes to the " .. Next .. " place.", Next
	end
	local Slot = MenuData.Slot(Player)
	MenuData.Release(Player) -- saved now, so the next place loads the new character
	-- FlowTeleport retries; if every try fails (now or later) the slot is loaded again here
	local Ok = FlowTeleport.Send(Player, PlaceId, {From = "Menu", Slot = Slot}, function(P) MenuData.Reload(P) end)
	if not Ok then
		-- (answer once the slot is back, so Play works again straight away)
		local Deadline = os.clock() + 15
		while not MenuData.Get(Player) and Player.Parent and os.clock() < Deadline do task.wait(0.1) end
		return false, "Teleport failed. Try again."
	end
	return true, nil, Next
end

ReplicatedStorage.Remotes.MenuRemote.OnServerInvoke = function(Player, Call, Arg)
	if Call == "State" then return State(Player) end
	if Call == "Slots" then return SlotList(Player) end
	if Call == "Plus" then return PlusState(Player) end
	if Call == "Hair" then
		local Id = Customization.ParseHairId(tostring(Arg))
		if not Id then return false, "That isn't a Roblox ID." end
		local Template, Why = AppearanceService.LoadHair(Id)
		return Template ~= nil, Why
	end
	if Busy[Player] then return false, "One moment..." end
	Busy[Player] = true
	local Ok, A, B, C = pcall(function()
		if Call == "Open" then
			local Profile, Why = MenuData.Open(Player, Arg)
			if not Profile then return false, Why end
			return true, nil, State(Player)
		end
		if Call == "RollClan" then return RollClan(Player) end
		if Call == "Favorite" then
			local Account = MenuData.Account(Player)
			if not Account then return false end
			local Slot = Arg == Account.Favorite and 0 or Arg
			if not SlotAccount.SetFavorite(Player.UserId, Slot) then return false, "Couldn't star that slot." end
			Account.Favorite = Slot
			return true
		end
		if Call == "Delete" then return MenuData.Delete(Player, Arg) end
		if Call == "Redeem" then return Redeem(Player, Arg) end
		if Call == "Create" then return Create(Player, Arg) end
		if Call == "Play" then return Play(Player) end
		if Call == "SaveLook" then
			if type(Arg) ~= "table" then return false, "Something went wrong." end
			return SetLook(Player, Arg.Index, Arg.Look)
		end
		if Call == "ClearLook" then return SetLook(Player, Arg, nil) end
		return false, "Unknown request."
	end)
	Busy[Player] = nil
	if not Ok then
		warn("MenuRemote", Call, "failed:", A)
		return false, "Something went wrong."
	end
	return A, B, C
end

-- Slot purchases (one more save slot per purchase, up to Slots.Max).
local function PackFor(ProductId)
	for _, P in ipairs(Clans.RerollPacks) do
		if P.Id ~= 0 and P.Id == ProductId then return P end
	end
end

local function ProcessReceipt(Info)
	-- Creator Plus (the Developer Product): saved on the account before the purchase is granted
	if CreatorPlus.ProductId ~= 0 and Info.ProductId == CreatorPlus.ProductId then
		local Result = SlotAccount.GrantPlus(Info.PlayerId, Info.PurchaseId)
		if not Result then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local Player = Players:GetPlayerByUserId(Info.PlayerId)
		if Player then MenuData.Account(Player, true) end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- clan rerolls: onto the open save slot (not open = try again later, when it is)
	local Pack = PackFor(Info.ProductId)
	if Pack then
		local Player = Players:GetPlayerByUserId(Info.PlayerId)
		local Profile = Player and MenuData.Get(Player)
		if not Profile or not Profile:IsActive() then return Enum.ProductPurchaseDecision.NotProcessedYet end
		-- (data-storage audit 2026-10-18) The purchase id goes in the profile's MetaTags, which also survive a
		-- character wipe (Gate permadeath), and the purchase is only reported granted once a save that includes it
		-- is confirmed (ProfileService's documented pattern). It used to be reported granted at once: a server that
		-- went down before the next auto-save lost the rolls, and Roblox would never retry the receipt.
		local I = Profile.Data.Identity
		local Legacy = type(I.RerollReceipts) == "table" and I.RerollReceipts or {}
		if table.find(Legacy, Info.PurchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end -- granted before
		local Ids = Profile.MetaData.MetaTags.RerollPurchases
		if type(Ids) ~= "table" then Ids = {} end
		if not table.find(Ids, Info.PurchaseId) then
			I.PaidClanRolls = (I.PaidClanRolls or 0) + Pack.Rolls
			table.insert(Ids, Info.PurchaseId)
			while #Ids > 30 do table.remove(Ids, 1) end
			Profile:SetMetaTag("RerollPurchases", Ids)
		end
		local Decision
		local function Check()
			local Saved = Profile.MetaData.MetaTagsLatest.RerollPurchases
			if type(Saved) == "table" and table.find(Saved, Info.PurchaseId) then Decision = Enum.ProductPurchaseDecision.PurchaseGranted end
		end
		Check()
		local Conn = Profile.MetaTagsUpdated:Connect(function()
			Check()
			if not Decision and not Profile:IsActive() then Decision = Enum.ProductPurchaseDecision.NotProcessedYet end
		end)
		local Deadline = os.clock() + 90 -- an auto-save comes every ~30 s
		while not Decision and os.clock() < Deadline do task.wait(0.1) end
		Conn:Disconnect()
		-- not confirmed yet: Roblox asks again later; the MetaTag stops a second grant
		return Decision or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Slots.ProductId == 0 or Info.ProductId ~= Slots.ProductId then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local Result = SlotAccount.Grant(Info.PlayerId, Info.PurchaseId)
	if not Result then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if Result == "Full" then warn("Slot purchase past the max for", Info.PlayerId, Info.PurchaseId) end
	local Player = Players:GetPlayerByUserId(Info.PlayerId)
	if Player then MenuData.Account(Player, true) end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MarketplaceService.ProcessReceipt = ProcessReceipt
-- Studio only: the callback can't be read back, so audits call it through this (never created on a live server)
if game:GetService("RunService"):IsStudio() then
	local Hook = Instance.new("BindableFunction")
	Hook.Name = "StudioReceiptTest"
	Hook.OnInvoke = ProcessReceipt
	Hook.Parent = script
end

Players.PlayerRemoving:Connect(function(Player) Busy[Player] = nil PlusOwned[Player] = nil end)

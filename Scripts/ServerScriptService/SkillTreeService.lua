-- SkillTreeService: buying and refunding Mastery skill-tree nodes (server-authoritative), and
-- publishing what the owned nodes do. Rules: Modules.Data.Rensei.SkillTree (the same verdict the
-- UI shows). Spec: Documents/specs/2026-10-15-skill-tree-design.md.
--   Buy(Player, Id, ExpectedRank) / Refund(Player, Id) -> ok, reason
--   Equip(Player, Id, Slot) / Unequip(Player, Family, Slot) -> ok, reason: the class-skill loadout
--     (Rensei.ClassSkills; profile SkillLoadout[Family]). Refunding a class skill also takes it off.
--   Publish(Player): every owned modifier as the character attribute Mod_<Key> (read through
--     Managers.SkillMods), plus the resource maxima. Called on spawn (ProgressionService.ApplyCharacter)
--     and after every purchase / refund.
-- Not during combat: in Combat Mode, or hit in the last COMBAT_LOCK seconds (attribute LastHitAt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillTree = require(ReplicatedStorage.Modules.Data.Rensei.SkillTree)
local ClassSkills = require(ReplicatedStorage.Modules.Data.Rensei.ClassSkills)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)

local COMBAT_LOCK = 5 -- PROPOSAL

local SkillTreeService = {}

local function PS() return require(ServerScriptService.ProgressionService) end

local function InCombat(Character)
	if not Character then return false end
	if Character:GetAttribute("CombatMode") == true then return true end
	return (Character:GetAttribute("LastHitAt") or 0) > workspace:GetServerTimeNow() - COMBAT_LOCK
end

function SkillTreeService.Publish(Player)
	local Data = PS().GetData(Player)
	local Character = Player.Character
	if not Data or not Character then return end
	for Name in pairs(Character:GetAttributes()) do
		if Name:sub(1, 4) == "Mod_" then Character:SetAttribute(Name, nil) end
	end
	local Mods = SkillTree.Modifiers(Data)
	for Key, Value in pairs(Mods) do Character:SetAttribute("Mod_" .. Key, Value) end
	-- resource maxima (Endurance, Attunement)
	for _, Name in ipairs({"Stamina", "Meter"}) do
		local Rule = ResourceManager.Rules[Name]
		if Rule then Character:SetAttribute("Max" .. Name, Rule.Max + (Mods["Max" .. Name] or 0)) end
	end
end

local function Changed(Player)
	local P = PS()
	P.ApplyCharacter(Player) -- max health (Toughness, Vigor) + Publish
	P.Sync(Player)
end

function SkillTreeService.Buy(Player, Id, ExpectedRank)
	local Data = PS().GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Id) ~= "string" or (ExpectedRank ~= nil and type(ExpectedRank) ~= "number") then return false, "Malformed request" end
	if InCombat(Player.Character) then return false, "Not during combat" end
	local Ok, Why = SkillTree.CanBuy(Data, Id, ExpectedRank)
	if not Ok then return false, Why end
	local Node = SkillTree.Nodes[Id]
	local Spent, SpendWhy = PS().SpendMastery(Player, Node.Cost)
	if not Spent then return false, SpendWhy end
	Data.SkillTree = Data.SkillTree or {}
	Data.SkillTree[Id] = (Data.SkillTree[Id] or 0) + 1
	Data.Mastery.StageSpend = Data.Mastery.StageSpend or {}
	Data.Mastery.StageSpend[Id] = (Data.Mastery.StageSpend[Id] or 0) + 1
	Changed(Player)
	return true
end

function SkillTreeService.Refund(Player, Id)
	local Data = PS().GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Id) ~= "string" then return false, "Malformed request" end
	if InCombat(Player.Character) then return false, "Not during combat" end
	local Ok, Why = SkillTree.CanRefund(Data, Id)
	if not Ok then return false, Why end
	local Node = SkillTree.Nodes[Id]
	local Back, BackWhy = PS().RefundMastery(Player, Node.Cost)
	if not Back then return false, BackWhy end
	Data.SkillTree[Id] -= 1
	if Data.SkillTree[Id] <= 0 then Data.SkillTree[Id] = nil end
	Data.Mastery.StageSpend[Id] -= 1
	if Data.Mastery.StageSpend[Id] <= 0 then Data.Mastery.StageSpend[Id] = nil end
	-- a refunded class skill comes off its loadout
	if Node.Tree == SkillTree.ClassTree and not Data.SkillTree[Id] and Data.SkillLoadout and Data.SkillLoadout[Node.Family] then
		for Slot, Equipped in pairs(Data.SkillLoadout[Node.Family]) do
			if Equipped == Id then Data.SkillLoadout[Node.Family][Slot] = "" end
		end
	end
	Changed(Player)
	return true
end

-- The saved loadout of a family, created / padded to ClassSkills.Slots entries.
local function LoadoutTable(Data, Family)
	Data.SkillLoadout = type(Data.SkillLoadout) == "table" and Data.SkillLoadout or {}
	local L = type(Data.SkillLoadout[Family]) == "table" and Data.SkillLoadout[Family] or {}
	for Slot = 1, ClassSkills.Slots do
		if type(L[Slot]) ~= "string" then L[Slot] = "" end
	end
	for Key in pairs(L) do
		if type(Key) ~= "number" or Key < 1 or Key > ClassSkills.Slots then L[Key] = nil end
	end
	Data.SkillLoadout[Family] = L
	return L
end

-- Put a learned class skill in a slot of its family's loadout. Already in another slot: it moves (a
-- skill is never equipped twice). The slot's previous skill comes off.
function SkillTreeService.Equip(Player, Id, Slot)
	local Data = PS().GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Id) ~= "string" then return false, "Malformed request" end
	if InCombat(Player.Character) then return false, "Not during combat" end
	local Ok, Why = ClassSkills.CanEquip(Data, Id, Slot)
	if not Ok then return false, Why end
	local L = LoadoutTable(Data, ClassSkills.Node(Id).Family)
	for S, Equipped in ipairs(L) do
		if Equipped == Id then L[S] = "" end
	end
	L[Slot] = Id
	PS().Sync(Player)
	return true
end

function SkillTreeService.Unequip(Player, Family, Slot)
	local Data = PS().GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Family) ~= "string" or not ClassSkills.Families[Family] then return false, "Malformed request" end
	if type(Slot) ~= "number" or Slot % 1 ~= 0 or Slot < 1 or Slot > ClassSkills.Slots then return false, "No such slot" end
	if InCombat(Player.Character) then return false, "Not during combat" end
	LoadoutTable(Data, Family)[Slot] = ""
	PS().Sync(Player)
	return true
end

return SkillTreeService

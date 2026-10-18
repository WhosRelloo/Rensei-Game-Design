-- ClassSkills: which class skills a character can use, and its loadout (owner 2026-10-17).
-- Shared: the server decides (SkillTreeService equip / unequip, Requests.ClassSkill use) and the UI
-- (MasteryUI's Class tab, the HUD hotbar) shows the same verdicts.
--
-- A skill belongs to one FAMILY. A family covers one or more weapon classes (TuningConfig.Weapons; "Unarmed" =
-- no weapon). Each family keeps its own loadout of Slots skills, saved as profile SkillLoadout[Family] =
-- {Id or "", ...}: changing weapons switches to that family's loadout and deletes nothing. In Combat Mode the
-- hotbar's keys 1..Slots use the current family's loadout (out of Combat Mode they hold items as before).
-- Learning a skill is a Mastery-tree purchase (Rensei.SkillTree, Tree "Class"); this module only covers
-- compatibility and loadouts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTree = require(ReplicatedStorage.Modules.Data.Rensei.SkillTree)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local ClassSkills = {}

ClassSkills.Slots = 4 -- PROPOSAL: hotbar keys 1-4 in Combat Mode
ClassSkills.Order = {"Fists", "Sword", "Rapier", "Greatsword", "Daggers", "Guns"}
-- The skill sheet's "Fist" skills fit both bare fists and the Caestus gauntlets (the sheet's "Caestus
-- (Fists)" row). Change here if a family should cover different classes.
ClassSkills.Families = {
	Fists = {Unarmed = true, Gauntlets = true},
	Sword = {Sword = true},
	Rapier = {Rapier = true},
	Greatsword = {Greatsword = true},
	Daggers = {Daggers = true},
	Guns = {Guns = true},
}
ClassSkills.Display = {Fists = "Fists", Sword = "Sword", Rapier = "Rapier", Greatsword = "Greatsword", Daggers = "Daggers", Guns = "Guns"}

-- The family of a weapon class (nil / "" = unarmed), or nil.
function ClassSkills.FamilyOf(WeaponClass)
	local Key = (WeaponClass == nil or WeaponClass == "") and "Unarmed" or WeaponClass
	for _, Family in ipairs(ClassSkills.Order) do
		if ClassSkills.Families[Family][Key] then return Family end
	end
	return nil
end

-- The family a character fights as right now (the Weapon attribute WeaponManager sets).
function ClassSkills.CharacterFamily(Character)
	return ClassSkills.FamilyOf(Character and Character:GetAttribute("Weapon"))
end

-- A family's skill nodes in column order (tier).
function ClassSkills.Nodes(Family)
	local List = {}
	for _, Node in pairs(SkillTree.Nodes) do
		if Node.Tree == SkillTree.ClassTree and Node.Family == Family then table.insert(List, Node) end
	end
	table.sort(List, function(A, B) return A.A < B.A end)
	return List
end

function ClassSkills.Node(Id)
	local Node = SkillTree.Nodes[Id]
	return Node and Node.Tree == SkillTree.ClassTree and Node or nil
end

-- The combat definition (TuningConfig.ClassSkills) of a class-skill node, or nil.
function ClassSkills.Def(Id)
	local Node = ClassSkills.Node(Id)
	return Node and Tuning.ClassSkills[Node.Skill] or nil
end

function ClassSkills.Learned(Data, Id)
	return ClassSkills.Node(Id) ~= nil and SkillTree.Rank(Data, Id) > 0
end

-- {[1..Slots] = Id or ""}: a copy of the saved loadout with anything unknown, unlearned or from another
-- family read as empty (a retired skill never breaks a loadout).
function ClassSkills.Loadout(Data, Family)
	local Saved = Data and Data.SkillLoadout and Data.SkillLoadout[Family] or {}
	local Out = {}
	for Slot = 1, ClassSkills.Slots do
		local Id = Saved[Slot]
		local Node = type(Id) == "string" and ClassSkills.Node(Id)
		Out[Slot] = (Node and Node.Family == Family and ClassSkills.Learned(Data, Id)) and Id or ""
	end
	return Out
end

function ClassSkills.SlotOf(Data, Family, Id)
	for Slot, Equipped in ipairs(ClassSkills.Loadout(Data, Family)) do
		if Equipped == Id then return Slot end
	end
	return nil
end

-- ok, reason
function ClassSkills.CanEquip(Data, Id, Slot)
	local Node = ClassSkills.Node(Id)
	if not Node then return false, "Unknown skill" end
	if type(Slot) ~= "number" or Slot % 1 ~= 0 or Slot < 1 or Slot > ClassSkills.Slots then return false, "No such slot" end
	if not ClassSkills.Learned(Data, Id) then return false, "Learn it first" end
	if not ClassSkills.Def(Id) then return false, "Not available yet" end
	return true
end

-- Whether a character's current class can use a skill (styles join when the style system exists).
function ClassSkills.Compatible(Character, Id)
	local Node = ClassSkills.Node(Id)
	return Node ~= nil and Node.Family == ClassSkills.CharacterFamily(Character)
end

return ClassSkills

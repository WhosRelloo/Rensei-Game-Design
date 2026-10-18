-- Rensei.Styles: weapon styles (owner prompt "three-style system for every weapon class", 2026-10-17).
-- A style is a combat moveset for one class: it replaces that class's light combo and heavy (numbers in
-- TuningConfig.Styles) and its idle / walk / block poses; everything else stays shared.
--
-- Classes are the combat movesets the code already has: "Fists" = BARE FISTS (no weapon; owner decision
-- 2026-10-17), plus the TuningConfig.Weapons classes (Gauntlets / Caestus keeps its own moveset).
-- Every class has the "Base" style = its existing moveset. CONFIRMED by the owner 2026-10-18 (decision 8:
-- "it should stay as selectable"): Base is a normal, selectable style, always learned (no trainer), and the
-- fallback when no other style is saved, so a class with no designed styles always has a valid one.
-- UNLOCKS (owner 2026-10-18): a style other than Base is learned ONLY from its style trainer (dialogue action
-- UnlockStyle) once its requirements are met (Unlock = {Trainer, Where, Level, Stats}); profile StyleUnlocks.
-- Styles marked Available = false are slots the style sheet hasn't filled yet: they are listed for the
-- team (NOT YET DESIGNED) and can never be selected.
--
-- Server: the character attribute "Style" holds the active style id for the class you're fighting as (set by
-- StyleService only; the client never sends attack data, just a style id to Requests.Style, validated).
local Styles = {}

Styles.Classes = {
	Fists = {Display = "Bare Fists", Order = {"Base", "Boxing", "Lethwei", "Third"}, Styles = {
		Base = {Name = "Brawler", Desc = "The standard fist moveset: balanced speed, reach and a knockback finisher.", Available = true}, -- the name "Brawler" is PROPOSAL
		Boxing = {Name = "Boxing", Available = true,
			Desc = "Tight guard and quick hands. Even jab chains keep them in range, you walk forward while punching, and the Peek-a-boo heavy rolls through hits.",
			Idle = "Boxing_Idle", Walk = "Boxing_Walk", Block = "Boxing_Block",
			Unlock = {Trainer = "Coach Harlan", Where = "the Lindenmoor square", Level = 4, Stats = {Speed = 4}}}, -- PROPOSAL
		Lethwei = {Name = "Lethwei", Available = true,
			Desc = "Elbows, knees and headbutts. Snappy close strikes that crush guards, but a whiff leaves you open. The finisher and heavy knock them away.",
			Idle = "Lethwei_Idle", Walk = "Lethwei_Walk", Block = "Lethwei_Block",
			Unlock = {Trainer = "Master Thura", Where = "the Lindenmoor farm, by the barn", Level = 6, Stats = {Strength = 5}}}, -- PROPOSAL
		Third = {Name = "Third style", Available = false, Desc = "NOT YET DESIGNED: no animations on the style sheet yet."},
	}},
}
-- weapon classes: Base only until their styles are designed on the sheet
for _, Class in ipairs({"Sword", "Rapier", "Greatsword", "Daggers", "Guns", "Gauntlets"}) do
	Styles.Classes[Class] = {Display = Class, Order = {"Base", "Style1", "Style2", "Style3"}, Styles = {
		Base = {Name = "Base", Desc = "This weapon's standard moveset.", Available = true},
		Style1 = {Name = "Style 1", Available = false, Desc = "NOT YET DESIGNED"},
		Style2 = {Name = "Style 2", Available = false, Desc = "NOT YET DESIGNED"},
		Style3 = {Name = "Style 3", Available = false, Desc = "NOT YET DESIGNED"},
	}}
end
Styles.Default = "Base"

-- the class a character is fighting as: its weapon class, or "Fists" bare-handed
function Styles.ClassOf(Character)
	local W = Character and Character:GetAttribute("Weapon")
	if W == nil or W == "" then return "Fists" end
	return Styles.Classes[W] and W or nil
end

function Styles.Valid(Class, Id)
	local C = Styles.Classes[Class]
	local S = C and C.Styles[Id]
	return S ~= nil and S.Available == true
end

-- the styles a player can pick for a class, in order
function Styles.Selectable(Class)
	local Out = {}
	local C = Styles.Classes[Class]
	for _, Id in ipairs(C and C.Order or {}) do if C.Styles[Id].Available then table.insert(Out, Id) end end
	return Out
end

-- learned? Base always; anything else only once its trainer taught it (profile StyleUnlocks[Id])
function Styles.Unlocked(Data, Id)
	if Id == Styles.Default then return true end
	return Data ~= nil and type(Data.StyleUnlocks) == "table" and Data.StyleUnlocks[Id] == true
end

local function Def(Id)
	for _, C in pairs(Styles.Classes) do if C.Styles[Id] then return C.Styles[Id] end end
end
Styles.Def = Def

-- what a player still needs before the trainer will teach a style: {"Level 4", "Speed 4"}; empty = ready
function Styles.Missing(Data, Id)
	local S = Def(Id)
	local U = S and S.Unlock
	local Out = {}
	if not U then return Out end
	if U.Level and ((Data and Data.Level) or 1) < U.Level then table.insert(Out, "Level " .. U.Level) end
	for Stat, Need in pairs(U.Stats or {}) do
		if ((Data and Data.Stats and Data.Stats[Stat]) or 1) < Need then table.insert(Out, Stat .. " " .. Need) end
	end
	table.sort(Out)
	return Out
end
function Styles.Ready(Data, Id) return Def(Id) ~= nil and Def(Id).Available == true and #Styles.Missing(Data, Id) == 0 end

-- the saved choice for a class (profile Styles[Class]), falling back to Base; only a learned style counts
function Styles.Saved(Data, Class)
	local Id = Data and type(Data.Styles) == "table" and Data.Styles[Class]
	return (Id and Styles.Valid(Class, Id) and Styles.Unlocked(Data, Id)) and Id or Styles.Default
end

-- active style id and its presentation data for a character (from the server-set attribute)
function Styles.Active(Character)
	local Class = Styles.ClassOf(Character)
	if not Class then return Styles.Default, nil, nil end
	local Id = Character:GetAttribute("Style")
	if not Styles.Valid(Class, Id) then Id = Styles.Default end
	return Id, Styles.Classes[Class].Styles[Id], Class
end

-- the combat numbers of the active style (TuningConfig.Styles[Class][Id]), or nil for Base
function Styles.Tuning(Character)
	local Id, _, Class = Styles.Active(Character)
	if Id == Styles.Default or not Class then return nil end
	local Tuning = require(script.Parent.TuningConfig)
	return Tuning.Styles[Class] and Tuning.Styles[Class][Id] or nil
end

return Styles

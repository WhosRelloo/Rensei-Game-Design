-- The Mastery skill tree's effects, as each system reads them. SkillTreeService (server) publishes
-- every owned modifier as the character attribute Mod_<Key>; this reads one (0 when absent).
-- Keys and meanings: Modules.Data.Rensei.SkillTree. Server and client read the same attributes.
local SkillMods = {}

function SkillMods.Get(Character, Key)
	return Character and tonumber(Character:GetAttribute("Mod_" .. Key)) or 0
end

-- 1 + the modifier: multiply a base value by it (a negative modifier shortens / weakens)
function SkillMods.Mult(Character, Key)
	return math.max(0.05, 1 + SkillMods.Get(Character, Key))
end

return SkillMods

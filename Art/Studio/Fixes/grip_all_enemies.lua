-- Every enemy can be knocked and gripped (owner 2026-10-20), except Def.Knockable = false (the Sparring dummy).
-- Knocked alchemists / Elites no longer raise a guard or parry. Backups: RenseiBackups["Pre-GripAll_2026-10-20"].
local SS = game:GetService("ServerStorage")
local B = SS.RenseiBackups:FindFirstChild("Pre-GripAll_2026-10-20") or Instance.new("Folder")
B.Name = "Pre-GripAll_2026-10-20"
B.Parent = SS.RenseiBackups
local function splice(script, edits)
	if not B:FindFirstChild(script.Name) then script:Clone().Parent = B end
	local src = script.Source
	for _, e in ipairs(edits) do
		local a = string.find(src, e[1], 1, true)
		assert(a, script.Name .. ": anchor not found: " .. e[1]:sub(1, 60))
		assert(not string.find(src, e[1], a + 1, true), script.Name .. ": anchor not unique: " .. e[1]:sub(1, 60))
		src = string.sub(src, 1, a - 1) .. e[2] .. string.sub(src, a + #e[1])
	end
	script.Source = src
	return #src
end
local ES = game.ServerScriptService.EnemyService
local n1 = splice(ES, {
	{'if Def.Knockable then Rig:SetAttribute("Knockable", true) end -- knocked at 0 HP, grip (B) to finish',
	 'if Def.Knockable ~= false then Rig:SetAttribute("Knockable", true) end -- every enemy is knocked at 0 HP, grip (B) to finish (owner 2026-10-20); Knockable = false opts out'},
	{'if Guard and E.Target == Attacker and Alive(Rig) and not Rig:GetAttribute("AIPassive") and not Swimming(Rig) then',
	 'if Guard and E.Target == Attacker and Alive(Rig) and not Rig:GetAttribute("AIPassive") and not Rig:GetAttribute("Knocked") and not Swimming(Rig) then'},
	{'if Def.ParryChance and E.Target == Attacker and Alive(Rig) and E.Block and not Rig:GetAttribute("GuardDown") and not Swimming(Rig) then',
	 'if Def.ParryChance and E.Target == Attacker and Alive(Rig) and E.Block and not Rig:GetAttribute("GuardDown") and not Rig:GetAttribute("Knocked") and not Swimming(Rig) then'},
})
local TC = game.ReplicatedStorage.Modules.Data.Rensei.TuningConfig
local n2 = splice(TC, {
	{'\tSparring = {\n', '\tSparring = {\n\t\tKnockable = false, -- the sparring dummy is never knocked (owner 2026-10-20: every other enemy is)\n'},
})
return ("EnemyService %d, TuningConfig %d; children ES %d TC %d"):format(n1, n2, #ES:GetChildren(), #TC:GetChildren())

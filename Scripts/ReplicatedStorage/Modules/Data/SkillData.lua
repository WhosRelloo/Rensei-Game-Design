-- Hitbox/damage definitions used by HitboxManager and DamageManager, keyed by skill name.
-- Built from TuningConfig so every combat number has one home.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local function From(Def, Extra)
	local T = {
		HitboxSize = Def.Hitbox,
		Reach = Def.Reach,
		Damage = Def.Damage,
		Posture = Def.Posture,
		StunTime = Def.Stun,
		VelocityType = Def.Velocity,
		Class = Def.Class,
	}
	for K, V in pairs(Extra or {}) do T[K] = V end
	return T
end

local SkillData = {}

for I, Hit in ipairs(Tuning.Light.Hits) do
	SkillData["Light" .. I] = From(Hit, {Meter = Tuning.Meter.OnLightHit})
end
SkillData.Heavy = From(Tuning.Heavy, {Meter = Tuning.Meter.OnHeavyHit})
SkillData.Uppercut = From(Tuning.Uppercut, {Meter = Tuning.Meter.OnLightHit})
SkillData.Aerial = From(Tuning.Aerial, {Meter = Tuning.Meter.OnLightHit})
SkillData.DashAttack = From(Tuning.DashAttack, {Meter = Tuning.Meter.OnLightHit})

-- Legacy names still referenced by older skill code (air heavy slam, uptilt).
SkillData.Fist = SkillData.Light1
SkillData.FistLast = SkillData.Light4
SkillData.FistHeavy = SkillData.Heavy
SkillData.Downslam = SkillData.Aerial
SkillData.JumpAttack = SkillData.Aerial

-- Styles (Rensei.Styles / TuningConfig.Styles): Style_<Id>_Light1..n, Style_<Id>_Heavy. Weapon = the class's
-- weapon (nil for bare fists), so weapon passives still only apply to that weapon's attacks.
for Class, List in pairs(Tuning.Styles or {}) do
	local Weapon = Tuning.Weapons[Class] and Class or nil
	for Id, S in pairs(List) do
		for I, Hit in ipairs(S.Light.Hits) do
			SkillData["Style_" .. Id .. "_Light" .. I] = From(Hit, {Meter = Tuning.Meter.OnLightHit, Weapon = Weapon})
		end
		SkillData["Style_" .. Id .. "_Heavy"] = From(S.Heavy, {Meter = Tuning.Meter.OnHeavyHit, Weapon = Weapon})
	end
end

-- Weapons: <Class>_Light1..n, <Class>_Heavy, <Class>_Skill (+ <Class>_SkillFinal for a skill with a
-- different last hit). Weapon = the class, so passives only apply to that weapon's own attacks.
for Class, W in pairs(Tuning.Weapons) do
	for I, Hit in ipairs(W.Light.Hits) do
		SkillData[Class .. "_Light" .. I] = From(Hit, {Meter = Tuning.Meter.OnLightHit, Weapon = Class})
	end
	SkillData[Class .. "_Heavy"] = From(W.Heavy, {Meter = Tuning.Meter.OnHeavyHit, Weapon = Class})
	-- guns' shooting mode (Requests.Shoot): <Class>_Shot1..n
	for I, Hit in ipairs(W.Shots or {}) do
		SkillData[Class .. "_Shot" .. I] = From(Hit, {Meter = Tuning.Meter.OnLightHit, Weapon = Class})
	end
	SkillData[Class .. "_Skill"] = From(W.Skill, {Meter = Tuning.Meter.OnLightHit, Weapon = Class})
	SkillData[Class .. "_DashAttack"] = From(W.DashAttack, {Meter = Tuning.Meter.OnLightHit, Weapon = Class})
	if W.Skill.Final then
		local Final = From(W.Skill, {Meter = Tuning.Meter.OnHeavyHit, Weapon = Class})
		Final.Damage = W.Skill.Final.Damage or Final.Damage
		Final.Posture = W.Skill.Final.Posture or Final.Posture
		Final.StunTime = W.Skill.Final.Stun or Final.StunTime
		Final.VelocityType = W.Skill.Final.Velocity or Final.VelocityType
		SkillData[Class .. "_SkillFinal"] = Final
	end
end

-- Class skills (TuningConfig.ClassSkills; Requests.ClassSkill): Class_<Id>, Class_<Id>Final (the last
-- hit's overrides), Class_<Id>Grab (the grab: little damage, holds the victim for Grab.Hold seconds).
for Id, Def in pairs(Tuning.ClassSkills or {}) do
	local Name = "Class_" .. Id
	SkillData[Name] = From(Def, {Meter = Tuning.Meter.OnLightHit, ClassSkill = Id})
	if Def.Final then
		local Final = From(Def, {Meter = Tuning.Meter.OnHeavyHit, ClassSkill = Id})
		Final.Damage = Def.Final.Damage or Final.Damage
		Final.Posture = Def.Final.Posture or Final.Posture
		Final.StunTime = Def.Final.Stun or Final.StunTime
		Final.VelocityType = Def.Final.Velocity or Final.VelocityType
		SkillData[Name .. "Final"] = Final
	end
	if Def.Grab then
		local Grab = From(Def, {Meter = Tuning.Meter.OnLightHit, ClassSkill = Id})
		Grab.Damage = Def.Grab.Damage
		Grab.Posture = Def.Grab.Posture or 0
		Grab.StunTime = Def.Grab.Hold
		Grab.VelocityType = nil
		Grab.Class = Def.GrabClass
		SkillData[Name .. "Grab"] = Grab
	end
end

-- Hitstop: heavier hits pause longer.
local function IsHeavyHit(Name)
	return Name == "Heavy" or Name == "FistHeavy" or Name == "Smash" or Name == "FistLast"
		or Name:match("Light4$") ~= nil or Name:match("_Heavy$") ~= nil or Name:match("_SkillFinal$") ~= nil
		or (Name:sub(1, 6) == "Class_" and Name:match("Final$") ~= nil)
end
for Name, Info in pairs(SkillData) do
	Info.Hitstop = IsHeavyHit(Name) and Tuning.Hitstop.Heavy or Tuning.Hitstop.Light
	-- heavy weapons (greatsword) hit with a longer impact pause on every hit
	local W = Info.Weapon and Tuning.Weapons[Info.Weapon]
	if W and W.HitstopMult then Info.Hitstop = Tuning.Hitstop.Heavy * W.HitstopMult end
end
-- Alchemy: Alchemy_<AbilityId> for every built ability (TuningConfig.Alchemy.Abilities), plus
-- Alchemy_<AbilityId><Part> for abilities that hit in several parts (Impl.Hits, e.g. Phoenix Drive's
-- Crash + Explosion). Damage and class come from the design sheet (Rensei.Alchemy); a part may set
-- its own share of the sheet's damage. Alchemy = true makes the hit scale with the caster's Alchemy
-- stat. Meter = 0: alchemy spends the Transmutation Meter, it never refills it. No hitstop.
do
	local Registry = require(ReplicatedStorage.Modules.Data.Rensei.Alchemy)
	for Id, Impl in pairs(Tuning.Alchemy.Abilities) do
		local Row = Registry.Abilities[Id]
		local function Make(Part)
			Part = Part or {}
			return {
				Damage = Part.Damage or Row.Damage, Class = Part.Class or Row.Class,
				Posture = Part.Posture or Impl.Posture, StunTime = Part.Stun or Impl.Stun,
				VelocityType = Part.Velocity or Impl.Velocity,
				Velocity = Part.Knockback or Impl.Knockback, VelocityDuration = Part.KnockbackTime or Impl.KnockbackTime,
				HitboxSize = Impl.Hitbox, Reach = Impl.Reach,
				Alchemy = true, Meter = 0, Ability = Id,
				BreaksShields = Impl.BreaksShields, TrueDamage = Part.TrueDamage or Impl.TrueDamage,
			}
		end
		SkillData["Alchemy_" .. Id] = Make()
		for PartName, Part in pairs(Impl.Hits or {}) do
			SkillData["Alchemy_" .. Id .. PartName] = Make(Part)
		end
	end
end

-- Combat Read's unblockable strike (a heavy no guard or parry stops; dodge it)
SkillData.DrillUnblockable = From(Tuning.Heavy, {Class = "UNBLOCKABLE", Meter = 0})
SkillData.Uptilt = From(Tuning.Light.Hits[1], {VelocityType = "Uptilt", Meter = Tuning.Meter.OnLightHit})
SkillData.Smash = From(Tuning.Heavy, {HitboxSize = Vector3.new(10, 8, 10), Meter = Tuning.Meter.OnHeavyHit})

return SkillData

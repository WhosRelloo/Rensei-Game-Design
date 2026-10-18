-- Rensei Mastery skill tree (spec: Documents/specs/2026-10-15-skill-tree-design.md, owner-approved
-- 2026-10-15). Three trees, one per tab: [Path] Alchemy / Arms / Body. Each is drawn as a
-- transmutation circle: a free root in the centre, then rings Comprehension (1) -> Deconstruction (2)
-- -> Reconstruction (3), opened by Mastery stage. Nodes cost Mastery Points (MP); forks are
-- exclusive; deeper rings need a stat. Every number is a PROPOSAL.
-- Shared by the server (SkillTreeService decides) and the client (MasteryUI shows the same verdict).

local SkillTree = {}

SkillTree.Trees = {"Alchemy", "Arms", "Body"}
SkillTree.Roots = {Alchemy = "AL_Root", Arms = "AR_Root", Body = "BO_Root"}
SkillTree.RingNames = {[1] = "Comprehension", [2] = "Deconstruction", [3] = "Reconstruction"}
SkillTree.RingStage = {[1] = 1, [2] = 2, [3] = 4} -- the stage a ring opens at
SkillTree.StatReq = {[2] = 8, [3] = 14} -- the tree stat a ring needs
SkillTree.TreeStats = {Alchemy = {"Alchemy"}, Arms = {"Strength", "Speed"}, Body = {"Vitality", "Speed"}}

local Nodes = {}
SkillTree.Nodes = Nodes

-- N(Id, Name, Tree, Ring, R, A, Type, Ranks, Cost, Req, Effects, Opt)
-- Effects: {{Key, Add}} per rank. Opt: Fork, Stat (override list), Slot, Preview, Text (card line).
local function N(Id, Name, Tree, Ring, R, A, Type, Ranks, Cost, Req, Effects, Opt)
	Opt = Opt or {}
	Nodes[Id] = {
		Id = Id, Name = Name, Tree = Tree, Ring = Ring, R = R, A = A, Type = Type,
		Ranks = Ranks, Cost = Cost, Req = Req, Effects = Effects or {},
		Fork = Opt.Fork, Stat = Opt.Stat or SkillTree.TreeStats[Tree], StatReq = SkillTree.StatReq[Ring],
		Slot = Opt.Slot, Preview = Opt.Preview, Text = Opt.Text,
		Family = Opt.Family, Skill = Opt.Skill, Level = Opt.Level, Styles = Opt.Styles, -- class skills
	}
end

local function Alc(Slot) return {Kind = "Alchemy", Slot = Slot} end
local function Anim(Name) return {Kind = "Anim", Anim = Name} end
local function Stat(Label, Base, Unit) return {Kind = "Stat", Label = Label, Base = Base, Unit = Unit or ""} end

-- ===== Roots (free, owned by everyone) =====
N("AL_Root", "Understanding", "Alchemy", 0, 0, 0, "Root", 1, 0, {}, {}, {Slot = "Z", Preview = Alc("Z"), Text = "Your first transmutation: the Z move."})
N("AR_Root", "Fundamentals", "Arms", 0, 0, 0, "Root", 1, 0, {}, {}, {Preview = Anim("FistCombo5"), Text = "The basics of fighting: your M1 string, heavy and feint."})
N("BO_Root", "Conditioning", "Body", 0, 0, 0, "Root", 1, 0, {}, {}, {Preview = Anim("FrontRoll"), Text = "A trained body: dash, climb and run."})

-- ===== Alchemy =====
N("AL_X", "Second Transmutation", "Alchemy", 1, 1.0, 0, "Move", 1, 3, {"AL_Root"}, {{"UnlockX", 1}}, {Slot = "X", Preview = Alc("X"), Text = "Unlocks your X move."})
N("AL_C", "Third Transmutation", "Alchemy", 1, 1.6, -15, "Move", 1, 4, {"AL_X"}, {{"UnlockC", 1}}, {Slot = "C", Preview = Alc("C"), Text = "Unlocks your C move."})
N("AL_QuickClap", "Quick Clap", "Alchemy", 1, 1.0, 70, "Upgrade", 2, 2, {"AL_Root"}, {{"ClapSpeed", 0.08}}, {Preview = Alc("Z"), Text = "The clap is 8% faster per rank."})
N("AL_Attune", "Attunement", "Alchemy", 1, 1.0, 140, "Passive", 2, 2, {"AL_Root"}, {{"MaxMeter", 10}}, {Preview = Stat("Max meter", 100), Text = "+10 max Transmutation Meter per rank."})
N("AL_ZPot", "Z Potency", "Alchemy", 1, 1.0, -70, "Upgrade", 3, 1, {"AL_Root"}, {{"ZDamage", 0.06}}, {Slot = "Z", Preview = Alc("Z"), Text = "Your Z move deals +6% per rank."})
N("AL_ZFocus", "Z Focus", "Alchemy", 1, 1.6, -70, "Upgrade", 2, 1, {"AL_ZPot"}, {{"ZCooldown", -0.08}}, {Slot = "Z", Preview = Alc("Z"), Text = "Your Z cooldown is 8% shorter per rank."})
N("AL_XPot", "X Potency", "Alchemy", 1, 1.6, 20, "Upgrade", 2, 2, {"AL_X"}, {{"XDamage", 0.06}}, {Slot = "X", Preview = Alc("X"), Text = "Your X move deals +6% per rank."})
N("AL_CFocus", "C Focus", "Alchemy", 1, 1.6, -40, "Upgrade", 2, 2, {"AL_C"}, {{"CCooldown", -0.08}}, {Slot = "C", Preview = Alc("C"), Text = "Your C cooldown is 8% shorter per rank."})
N("AL_V", "Grand Transmutation", "Alchemy", 2, 2.3, -15, "Move", 1, 6, {"AL_C"}, {{"UnlockV", 1}}, {Slot = "V", Preview = Alc("V"), Text = "Unlocks your V move, the ultimate."})
N("AL_Charged", "Charged Clap", "Alchemy", 2, 2.3, 70, "Upgrade", 2, 2, {"AL_QuickClap"}, {{"HeldClapDamage", 0.05}}, {Preview = Alc("Z"), Text = "Holding the clap for 1s+ makes the move +5% stronger per rank."})
N("AL_Momentum", "Alchemic Momentum", "Alchemy", 2, 2.3, 140, "Passive", 2, 2, {"AL_Attune"}, {{"MeterOnHit", 1}}, {Preview = Stat("Meter per light hit", 4), Text = "+1 meter per light hit per rank."})
N("AL_Steady", "Steady Array", "Alchemy", 2, 2.7, 55, "Upgrade", 1, 3, {"AL_Charged"}, {{"CastWalkSpeed", 1}}, {Fork = "A1", Preview = Alc("Z"), Text = "Walk at full speed while casting."})
N("AL_Swift", "Swift Array", "Alchemy", 2, 2.7, 85, "Upgrade", 1, 3, {"AL_Charged"}, {{"Windup", -0.10}}, {Fork = "A1", Preview = Alc("Z"), Text = "Every move's windup is 10% shorter."})
N("AL_VPot", "V Potency", "Alchemy", 2, 2.7, -30, "Upgrade", 2, 2, {"AL_V"}, {{"VDamage", 0.06}}, {Slot = "V", Preview = Alc("V"), Text = "Your V move deals +6% per rank."})
N("AL_CPot", "C Potency", "Alchemy", 2, 2.3, -45, "Upgrade", 2, 2, {"AL_C"}, {{"CDamage", 0.06}}, {Slot = "C", Preview = Alc("C"), Text = "Your C move deals +6% per rank."})
N("AL_Exchange", "Equivalent Exchange", "Alchemy", 3, 3.3, 125, "Keystone", 1, 5, {"AL_Momentum"}, {{"MeterRefund", 0.30}}, {Fork = "KA", Preview = Alc("Z"), Text = "A landed alchemy hit refunds 30% of its meter."})
N("AL_Blood", "Blood Price", "Alchemy", 3, 3.3, 155, "Keystone", 1, 5, {"AL_Momentum"}, {{"BloodCast", 2}}, {Fork = "KA", Preview = Alc("Z"), Text = "Out of meter, cast anyway by paying 2 HP per missing meter."})
N("AL_VFocus", "V Focus", "Alchemy", 3, 3.3, -30, "Upgrade", 2, 3, {"AL_VPot"}, {{"VCooldown", -0.08}}, {Slot = "V", Preview = Alc("V"), Text = "Your V cooldown is 8% shorter per rank."})
N("AL_Overflow", "Overflow", "Alchemy", 3, 3.3, 70, "Passive", 1, 4, {"AL_Charged"}, {{"OverflowDamage", 0.10}}, {Preview = Alc("Z"), Text = "Alchemy deals +10% when cast with 80+ meter."})
Nodes.AL_V.Stat = {"Alchemy"}

-- ===== Arms =====
N("AR_Finisher", "Finisher", "Arms", 1, 1.0, 0, "Upgrade", 2, 2, {"AR_Root"}, {{"FinisherDamage", 0.10}}, {Preview = Anim("FistCombo5"), Text = "The last hit of your M1 string deals +10% per rank."})
N("AR_Heavy", "Heavy Hand", "Arms", 1, 1.0, -60, "Upgrade", 2, 2, {"AR_Root"}, {{"HeavyCooldown", -0.10}}, {Preview = Anim("Heavy"), Text = "Heavy cooldown 10% shorter per rank."})
N("AR_Draw", "Drawn Steel", "Arms", 1, 1.0, 90, "Upgrade", 1, 1, {"AR_Root"}, {{"DrawSpeed", 0.30}}, {Preview = Anim("Sword_Equip"), Text = "Draw and sheathe 30% faster."})
N("AR_Feint", "Feint Discipline", "Arms", 1, 1.0, 200, "Upgrade", 1, 2, {"AR_Root"}, {{"FeintCost", -0.25}}, {Preview = Anim("FistCombo1"), Text = "Feints cost 25% less stamina."})
N("AR_Art", "Weapon Art", "Arms", 1, 1.6, 90, "Upgrade", 2, 2, {"AR_Draw"}, {{"SkillCooldown", -0.10}}, {Preview = Anim("Heavy"), Text = "Weapon skill (T) cooldown 10% shorter per rank."})
N("AR_Upper", "Uppercutter", "Arms", 1, 1.6, 25, "Upgrade", 1, 2, {"AR_Finisher"}, {{"UppercutCooldown", -0.20}}, {Preview = Anim("Uppercut"), Text = "Uppercut cooldown 20% shorter."})
N("AR_Riposte", "Riposte", "Arms", 2, 2.3, -75, "Upgrade", 1, 3, {"AR_Heavy"}, {{"Riposte", 1}}, {Fork = "R1", Preview = Anim("Parry1"), Text = "After a perfect parry, your next hit within 2s is a crit (+50%)."})
N("AR_Breaker", "Guard Breaker", "Arms", 2, 2.3, -45, "Upgrade", 1, 3, {"AR_Heavy"}, {{"HeavyPosture", 0.25}}, {Fork = "R1", Preview = Anim("Heavy"), Text = "Heavies deal +25% posture damage."})
N("AR_Blade", "Bladework", "Arms", 2, 2.3, 0, "Passive", 3, 2, {"AR_Finisher"}, {{"LightDamage", 0.04}}, {Preview = Anim("FistCombo2"), Text = "Light attacks deal +4% per rank."})
N("AR_Rush", "Momentum Strike", "Arms", 2, 2.3, 35, "Upgrade", 2, 2, {"AR_Upper"}, {{"DashAttackDamage", 0.10}}, {Preview = Anim("FistCombo1"), Text = "Dash attacks deal +10% per rank."})
N("AR_Marks", "Marksman", "Arms", 2, 2.3, 100, "Upgrade", 2, 2, {"AR_Art"}, {{"GunReload", -0.10}, {"GunRange", 0.10}}, {Stat = {"Speed"}, Preview = Anim("Heavy"), Text = "Guns: reload 10% faster and +10% range per rank."})
N("AR_Relentless", "Relentless", "Arms", 3, 3.3, -15, "Keystone", 1, 5, {"AR_Blade"}, {{"StringRamp", 0.03}}, {Fork = "KR", Preview = Anim("FistCombo3"), Text = "Each hit in a string deals +3% more, up to +9%."})
N("AR_Duelist", "Duelist", "Arms", 3, 3.3, 15, "Keystone", 1, 5, {"AR_Blade"}, {{"DuelDamage", 0.10}}, {Fork = "KR", Preview = Anim("FistCombo2"), Text = "+10% damage while only one enemy is within 20 studs."})
N("AR_Exec", "Executioner", "Arms", 3, 3.3, -60, "Upgrade", 1, 4, {"AR_Riposte", "AR_Breaker"}, {{"GripSpeed", 0.30}}, {Preview = Anim("FistCombo1"), Text = "Grip finishers are 30% faster."})
N("AR_Mastery", "Weapon Mastery", "Arms", 3, 3.3, 60, "Passive", 2, 3, {"AR_Blade", "AR_Marks"}, {{"WeaponPassive", 0.25}}, {Preview = Anim("Heavy"), Text = "Weapon passives are 25% stronger per rank."})

-- ===== Body =====
N("BO_Endure", "Endurance", "Body", 1, 1.0, 0, "Passive", 3, 1, {"BO_Root"}, {{"MaxStamina", 10}}, {Preview = Stat("Max stamina", 100), Text = "+10 max stamina per rank."})
N("BO_Climb", "Climber", "Body", 1, 1.0, 120, "Upgrade", 1, 2, {"BO_Root"}, {{"ParkourCost", -0.20}}, {Preview = Anim("RightClimb"), Text = "Climbing and wall runs cost 20% less stamina."})
N("BO_Step", "Quick Step", "Body", 1, 1.0, -120, "Upgrade", 2, 2, {"BO_Root"}, {{"DashCooldown", -0.10}}, {Preview = Anim("FrontRoll"), Text = "Dash cooldown 10% shorter per rank."})
N("BO_Tough", "Toughness", "Body", 1, 1.6, -20, "Passive", 2, 2, {"BO_Endure"}, {{"MaxHealth", 0.04}}, {Preview = Stat("Max health", nil, "%"), Text = "+4% max health per rank."})
N("BO_Compose", "Composure", "Body", 1, 1.6, 25, "Passive", 1, 2, {"BO_Endure"}, {{"PostureRegen", 0.20}}, {Preview = Stat("Posture recovery", nil, "%"), Text = "Posture recovers 20% faster."})
N("BO_Iron", "Iron Skin", "Body", 2, 2.3, -135, "Passive", 1, 3, {"BO_Step"}, {{"DamageTaken", -0.06}}, {Fork = "B1", Preview = Stat("Damage taken", nil, "%"), Text = "Take 6% less damage."})
N("BO_Light", "Light Feet", "Body", 2, 2.3, -105, "Upgrade", 1, 3, {"BO_Step"}, {{"DashIFrames", 0.05}}, {Fork = "B1", Preview = Anim("FrontRoll"), Text = "Dash i-frames last 0.05s longer."})
N("BO_Vigor", "Vigor", "Body", 2, 2.3, -25, "Passive", 2, 2, {"BO_Tough"}, {{"MaxHealth", 0.05}}, {Stat = {"Vitality"}, Preview = Stat("Max health", nil, "%"), Text = "+5% max health per rank."})
N("BO_Recover", "Recovery", "Body", 2, 2.3, 30, "Passive", 1, 3, {"BO_Compose"}, {{"StaminaRegen", 0.20}}, {Preview = Stat("Stamina recovery", nil, "%"), Text = "Stamina recovers 20% faster."})
N("BO_Runner", "Runner", "Body", 2, 2.3, 120, "Passive", 2, 2, {"BO_Climb"}, {{"SprintSpeed", 0.05}}, {Stat = {"Speed"}, Preview = Anim("Run"), Text = "Sprint 5% faster per rank."})
N("BO_Heavy", "Heavy Frame", "Body", 2, 2.7, 105, "Passive", 1, 3, {"BO_Runner"}, {{"KnockbackTaken", -0.30}}, {Fork = "B2", Preview = Stat("Knockback taken", nil, "%"), Text = "Get knocked back 30% less."})
N("BO_Acro", "Acrobat", "Body", 2, 2.7, 135, "Upgrade", 1, 3, {"BO_Runner"}, {{"WallRunTime", 0.25}}, {Fork = "B2", Preview = Anim("WallRunRight"), Text = "Wall runs last 25% longer."})
N("BO_Second", "Second Wind", "Body", 3, 3.3, -40, "Keystone", 1, 5, {"BO_Vigor"}, {{"SecondWind", 1}}, {Fork = "KB", Preview = Stat("Recover from a knock at", 15, "% HP"), Text = "Once per life, a knock recovers at 30% HP after 12s (instead of 15% after 20s)."})
N("BO_Unbroken", "Unbroken", "Body", 3, 3.3, -10, "Keystone", 1, 5, {"BO_Vigor"}, {{"PostureRegen", 0.5}, {"GuardBreakStun", -0.25}}, {Fork = "KB", Preview = Stat("Posture recovery", nil, "%"), Text = "Posture recovers 50% faster; guard-break stun is 25% shorter."})
N("BO_Fort", "Fortitude", "Body", 3, 3.3, 30, "Passive", 2, 3, {"BO_Recover"}, {{"DamageTaken", -0.04}}, {Preview = Stat("Damage taken", nil, "%"), Text = "Take 4% less damage per rank."})

-- ===== Class skills (owner 2026-10-17: a dedicated Class Skills column, equipped to the hotbar) =====
-- Tree "Class": not a circle -- MasteryUI draws it as one column per family (Rensei.ClassSkills), R = the
-- family's column, A = the row (tier). Learned with Mastery Points like every node (refundable until the
-- Truth/Gate trial seals the stage); all in ring 1, so every one is reachable before the trial exists.
-- Opt.Level = the character level it needs. Opt.Skill = its TuningConfig.ClassSkills entry. The names and
-- animations are the skill sheet's; costs, levels and chains are PROPOSALS.
SkillTree.ClassTree = "Class"
local function C(Id, Name, Family, Col, Row, Cost, Req, Level, Skill, Anim, Text)
	N(Id, Name, "Class", 1, Col, Row, "ClassSkill", 1, Cost, Req, {}, {Family = Family, Skill = Skill, Level = Level, Preview = {Kind = "Anim", Anim = Anim}, Text = Text})
end
C("CL_SpinKick", "Spin Kick", "Fists", 1, 1, 2, {}, 1, "SpinKick", "Fist_SpinKick", "One heavy spinning kick that knocks the target back.")
C("CL_BearHug", "Bear Hug", "Fists", 1, 2, 3, {}, 1, "BearHug", "Fist_BearHug", "Grab: lock the target in a crushing hold. Beats block and parry; a dodge escapes it. A miss leaves you open.")
C("CL_540Kick", "540 Kick", "Fists", 1, 3, 3, {"CL_SpinKick"}, 5, "Kick540", "Fist_540Kick", "A spinning jump kick: three kicks that latch on; the last one knocks back.")
C("CL_SlamDunk", "Slam Dunk", "Fists", 1, 4, 4, {"CL_BearHug"}, 5, "SlamDunk", "Fist_SlamDunk", "Grab, lift and slam the target into the ground. Beats block and parry; a dodge escapes it. Hyper armour while you hold them.")
C("CL_WhereYouGoing", "WHERE YOU GOING?!", "Fists", 1, 5, 5, {"CL_540Kick", "CL_SlamDunk"}, 10, "WhereYouGoing", "Fist_WhereYouGoing", "Chase down a fleeing target: a lunge into four blows that drag them back; the last knocks them away.")
C("CL_QuickDraw", "Quick Draw", "Sword", 2, 1, 2, {}, 1, "QuickDraw", "Sword_QuickDraw", "Dash forward and cut from the sheath in one motion.")
C("CL_IaidoBarrage", "Iaido Barrage", "Sword", 2, 2, 4, {"CL_QuickDraw"}, 5, "IaidoBarrage", "Sword_IaidoBarrage", "Four rapid draw-cuts; the last one knocks back.")
C("CL_SpeedLunge", "Speed Lunge", "Rapier", 3, 1, 2, {}, 1, "SpeedLunge", "Rapier_SpeedLunge", "A long, fast lunging thrust.")
C("CL_Ren", "Ren", "Rapier", 3, 2, 4, {"CL_SpeedLunge"}, 5, "Ren", "Rapier_Ren", "Leap in with two slashes and strike again on landing.")
C("CL_HeavyDrop", "Heavy Drop", "Greatsword", 4, 1, 3, {}, 1, "HeavyDrop", "Greatsword_HeavyDrop", "Two crushing overhead blows with hyper armour, stepping into the second.")
C("CL_WhirlwindCleave", "Whirlwind Cleave", "Greatsword", 4, 2, 4, {"CL_HeavyDrop"}, 5, "WhirlwindCleave", "Greatsword_WhirlwindCleave", "Spin the blade around you twice, hitting everything close. Hyper armour.")
C("CL_SlipSlash", "Slip Slash", "Daggers", 5, 1, 2, {}, 1, "SlipSlash", "Daggers_SlipSlash", "Two quick cuts; the second knocks back.")
C("CL_BulletSlash", "Bullet Slash", "Daggers", 5, 2, 3, {"CL_SlipSlash"}, 5, "BulletSlash", "Daggers_BulletSlash", "Shoot forward and cut twice.")
C("CL_BloodDash", "Blood Dash", "Daggers", 5, 3, 3, {"CL_SlipSlash"}, 5, "BloodDash", "Daggers_BloodDash", "Dash through the target with a cut that makes them bleed.")
C("CL_ComeHere", "COME HERE!!", "Daggers", 5, 4, 4, {"CL_BulletSlash", "CL_BloodDash"}, 10, "ComeHere", "Daggers_ComeHere", "Four cuts that drag the target in; the last knocks them away.")
C("CL_IronRush", "Iron Rush", "Guns", 6, 1, 3, {}, 1, "IronRush", "Guns_IronRush", "Rush in, grab and stab, then kick them away. Beats block and parry; a dodge escapes it. A miss leaves you open.")

-- ===== Rules (one verdict for server and UI) =====
local function Owned(Data) return (Data and Data.SkillTree) or {} end

function SkillTree.Rank(Data, Id)
	local Node = Nodes[Id]
	if not Node then return 0 end
	if Node.Type == "Root" then return 1 end
	return Owned(Data)[Id] or 0
end

function SkillTree.Stage(Data)
	return (Data and Data.Mastery and Data.Mastery.Stage) or 1
end

-- Owned rival in the same fork, or nil
function SkillTree.ForkRival(Data, Id)
	local Node = Nodes[Id]
	if not Node or not Node.Fork then return nil end
	for OtherId, Other in pairs(Nodes) do
		if OtherId ~= Id and Other.Fork == Node.Fork and SkillTree.Rank(Data, OtherId) > 0 then return Other end
	end
	return nil
end

local function BestStat(Data, Names)
	local Best = 0
	for _, S in ipairs(Names) do Best = math.max(Best, (Data and Data.Stats and Data.Stats[S]) or 0) end
	return Best
end

-- Every requirement with whether it's met: {{Text, Ok}} (the card's checklist). Prerequisites are
-- "any one of".
function SkillTree.Requirements(Data, Id)
	local Node = Nodes[Id]
	local List = {}
	if not Node or Node.Type == "Root" then return List end
	local Need = SkillTree.RingStage[Node.Ring]
	table.insert(List, {("Stage %d"):format(Need), SkillTree.Stage(Data) >= Need})
	if #Node.Req > 0 then
		local Names, Any = {}, false
		for _, R in ipairs(Node.Req) do
			table.insert(Names, Nodes[R].Name)
			if SkillTree.Rank(Data, R) > 0 then Any = true end
		end
		table.insert(List, {table.concat(Names, " or "), Any})
	end
	if Node.StatReq then
		table.insert(List, {("%s %d"):format(table.concat(Node.Stat, " or "), Node.StatReq), BestStat(Data, Node.Stat) >= Node.StatReq})
	end
	if Node.Level and Node.Level > 1 then
		table.insert(List, {("Level %d"):format(Node.Level), ((Data and Data.Level) or 1) >= Node.Level})
	end
	local Rival = SkillTree.ForkRival(Data, Id)
	if Node.Fork then table.insert(List, {Rival and ("Locked by " .. Rival.Name) or "Fork: excludes its pair", Rival == nil}) end
	return List
end

-- ok, reason
function SkillTree.CanBuy(Data, Id, ExpectedRank)
	local Node = Nodes[Id]
	if not Node or Node.Type == "Root" then return false, "Unknown skill" end
	if not Data or not Data.Mastery then return false, "Profile not loaded" end
	local Need = SkillTree.RingStage[Node.Ring]
	if SkillTree.Stage(Data) < Need then return false, ("Opens at Stage %d"):format(Need) end
	local Rank = SkillTree.Rank(Data, Id)
	if Rank >= Node.Ranks then return false, "Already maxed" end
	if ExpectedRank ~= nil and ExpectedRank ~= Rank then return false, "Out of date" end
	local Any = #Node.Req == 0
	for _, R in ipairs(Node.Req) do if SkillTree.Rank(Data, R) > 0 then Any = true end end
	if not Any then return false, "Needs " .. Nodes[Node.Req[1]].Name end
	local Rival = SkillTree.ForkRival(Data, Id)
	if Rival then return false, "Locked by " .. Rival.Name end
	if Node.StatReq and BestStat(Data, Node.Stat) < Node.StatReq then
		return false, ("Needs %s %d"):format(table.concat(Node.Stat, " or "), Node.StatReq)
	end
	if Node.Level and (Data.Level or 1) < Node.Level then return false, ("Needs level %d"):format(Node.Level) end
	if (Data.Mastery.Unspent or 0) < Node.Cost then return false, "Not enough Mastery Points" end
	return true
end

-- ok, reason. Only ranks bought this stage (Mastery.StageSpend) can be refunded, and never the last
-- link another owned node needs.
function SkillTree.CanRefund(Data, Id)
	local Node = Nodes[Id]
	if not Node or Node.Type == "Root" then return false, "Unknown skill" end
	if not Data or not Data.Mastery then return false, "Profile not loaded" end
	local Rank = SkillTree.Rank(Data, Id)
	if Rank < 1 then return false, "Not owned" end
	if ((Data.Mastery.StageSpend or {})[Id] or 0) < 1 then return false, "Sealed by the Truth/Gate trial" end
	if Rank == 1 then
		for OtherId, Other in pairs(Nodes) do
			if SkillTree.Rank(Data, OtherId) > 0 and Other.Type ~= "Root" and table.find(Other.Req, Id) then
				local Others = false
				for _, R in ipairs(Other.Req) do
					if R ~= Id and SkillTree.Rank(Data, R) > 0 then Others = true end
				end
				if not Others then return false, "Needed by " .. Other.Name end
			end
		end
	end
	return true
end

-- ===== Progression guide helpers (the Mastery menu's GUIDE tab, 2026-10-17) =====
-- The categories the owner's brief names, mapped onto the existing tabs (nothing is merged or moved):
SkillTree.CategoryOrder = {"Class Skills", "Combat Techniques", "Alchemy Skills", "Passive Skills & Traits", "Movement & Utility", "Mastery & Advanced"}
local MOVEMENT_KEYS = {ParkourCost = true, DashCooldown = true, DashIFrames = true, SprintSpeed = true, WallRunTime = true}
function SkillTree.Category(Node)
	if Node.Tree == SkillTree.ClassTree then return "Class Skills" end
	if Node.Type == "Keystone" or (Node.Ring or 1) >= 2 then return "Mastery & Advanced" end
	if Node.Tree == "Alchemy" then return "Alchemy Skills" end
	for _, E in ipairs(Node.Effects or {}) do
		if MOVEMENT_KEYS[E[1]] then return "Movement & Utility" end
	end
	if Node.Type == "Passive" then return "Passive Skills & Traits" end
	return "Combat Techniques"
end

-- What still stands between the player and a node: {{Kind, Text, Hint}}, empty when it can be bought.
-- Kind = "Stage" | "Prereq" | "Stat" | "Level" | "Fork" | "MP" | "Maxed". Hint says WHERE to get it.
local TAB_NAME = {Alchemy = "Alchemy", Arms = "Arms", Body = "Body", Class = "Class"}
function SkillTree.Missing(Data, Id)
	local Node = Nodes[Id]
	local Out = {}
	if not Node or Node.Type == "Root" or not Data or not Data.Mastery then return Out end
	if SkillTree.Rank(Data, Id) >= Node.Ranks then
		table.insert(Out, {"Maxed", "Already learned", ""})
		return Out
	end
	local Need = SkillTree.RingStage[Node.Ring]
	if SkillTree.Stage(Data) < Need then
		table.insert(Out, {"Stage", ("Stage %d"):format(Need),
			("Opens once you pass the Truth/Gate trial that ends stage %d (the trial isn't in the game yet)."):format(Need - 1)})
	end
	if #Node.Req > 0 then
		local Any, Names = false, {}
		for _, R in ipairs(Node.Req) do
			table.insert(Names, Nodes[R].Name)
			if SkillTree.Rank(Data, R) > 0 then Any = true end
		end
		if not Any then
			table.insert(Out, {"Prereq", "Learn " .. table.concat(Names, " or "),
				("Learn %s first (%s tab)."):format(table.concat(Names, " or "), TAB_NAME[Node.Tree] or Node.Tree)})
		end
	end
	if Node.StatReq and BestStat(Data, Node.Stat) < Node.StatReq then
		table.insert(Out, {"Stat", ("%s %d"):format(table.concat(Node.Stat, " or "), Node.StatReq),
			("Raise %s to %d with Stat Points (you get them by levelling up; spend them in Stats, M)."):format(table.concat(Node.Stat, " or "), Node.StatReq)})
	end
	if Node.Level and (Data.Level or 1) < Node.Level then
		table.insert(Out, {"Level", ("Level %d"):format(Node.Level),
			("Reach level %d (you're %d): EXP comes from defeating enemies, quests and investigations."):format(Node.Level, Data.Level or 1)})
	end
	local Rival = SkillTree.ForkRival(Data, Id)
	if Rival then
		table.insert(Out, {"Fork", "Locked by " .. Rival.Name,
			("You chose %s. Refund it (only until this stage's Truth/Gate trial) to take this instead."):format(Rival.Name)})
	end
	if (Data.Mastery.Unspent or 0) < Node.Cost then
		table.insert(Out, {"MP", ("%d Mastery Point%s (you have %d)"):format(Node.Cost, Node.Cost == 1 and "" or "s", Data.Mastery.Unspent or 0),
			"Earn Mastery Points by training: fighting (hits, parries, defeats), your trainer's lesson and exercises, exams and quests."})
	end
	return Out
end

-- {[Key] = summed value} for everything owned
function SkillTree.Modifiers(Data)
	local Mods = {}
	for Id, Node in pairs(Nodes) do
		local Rank = Node.Type == "Root" and 0 or SkillTree.Rank(Data, Id)
		if Rank > 0 then
			for _, E in ipairs(Node.Effects) do
				local Per = (Node.Type == "Move" or Node.Type == "Keystone") and E[2] or E[2] * Rank
				Mods[E[1]] = (Mods[E[1]] or 0) + Per
			end
		end
	end
	return Mods
end

-- MP spent in one tree
function SkillTree.SpentIn(Data, Tree)
	local Total = 0
	for Id, Node in pairs(Nodes) do
		if Node.Tree == Tree and Node.Type ~= "Root" then Total += SkillTree.Rank(Data, Id) * Node.Cost end
	end
	return Total
end

return SkillTree

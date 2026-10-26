-- Play_GunNpc (gun rework Task 11, 2026-10-25): enemy gunners' shots (EnemyService.GunShot), in the Play VM
-- (LMRunSuite). Every case uses GunKit's rigs at GunKit.Spot(): a Sykov shooter (an NPC rig) at the spot facing -Z, its
-- WCS character from WCS.Character.GetCharacterFromInstance, and a GunKit dummy as the target, inside SmokeKit.Guarded
-- with GunKit.Clean as After, after GunKit.Unequip (Ruling 4c). Every expected number is worked by hand below, as a
-- constant; nothing is read from the code under test to choose a spot or an answer.
--   TuningConfig Weapons.Guns.NpcShot (PROPOSAL): Startup 0.35, Telegraph, Spread 2.5 degrees. The Sykov's own shots
--   (Weapons.Guns.Shots) have Startup 0.12 and no Spread; Magazine 10.
--   GunKit's rigs: the root stands 3 over the floor; the muzzle is root + (0, 1.5, 0); a character's hit box (Aim.HitBox,
--   PROPOSAL) is 4 wide x 5 high x 2 deep, centred 0.5 below the root, so it spans the feet (root - 3) to root + 2.
--   HitsATargetAbove: the target stands on a LEDGE-stud block 15 studs ahead (its root at floor + 9). The old flat aim
--   leaves the muzzle level, at floor + 4.5: under the ledge's top (floor + 6), so its wall stops it 13 studs out and
--   nothing is hit. (The brief's 4-stud block can't fail: the box's bottom is the target's feet, on the block's top at
--   floor + 4, and the level line at floor + 4.5 clips the box's legs. With the box's bottom on the block's top, a level
--   line meets one or the other, so the block has to stand above floor + 4.5: 6 gives 1.5 studs.) The centre aim, muzzle
--   (floor + 4.5) to root (floor + 9), rises 4.5 over 15: 13 studs out (the ledge's near face) it is at floor + 8.4,
--   2.4 over the ledge's top, and 14 out (the box's near face) at floor + 8.7, inside the box (floor + 6 to + 11).
--   SpreadStaysInCone: the target 15 studs straight ahead at the shooter's height, so the line to it is muzzle -> root =
--   (0, -1.5, -15). GunAim.Spread turns that line by CFrame.Angles(Pitch, Yaw, 0) in CFrame.lookAt(0, line)'s frame, each
--   angle uniform in +-2.5 degrees; in that frame the shot is (-sin Yaw, sin Pitch cos Yaw, -cos Pitch cos Yaw), so
--   asin(-x) is the yaw and atan2(y, -z) the pitch, each within 2.5 degrees.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local EnemyService = require(SSS.EnemyService)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Player = game.Players:GetPlayers()[1]

local AHEAD = Vector3.new(0, 0, -1) -- every shooter faces -Z
local GUN = "Sykov"
local DIST = 15 -- studs from the shooter to the target
local WINDUP, WINDUP_EPS = 0.35, 0.05 -- seconds from Startup to Active (NpcShot.Startup; was the shot's own 0.12)
local LEDGE = 6 -- studs: HitsATargetAbove's block (worked above)
local LEDGE_FOOT = 4 -- studs: the block's width and depth
local LINE = Vector3.new(0, -1.5, -DIST).Unit -- SpreadStaysInCone: muzzle -> the target's root (worked above)
local SPREAD, SPREAD_EPS = 2.5, 1e-3 -- degrees per axis (NpcShot.Spread)
local SPREAD_SHOTS = 30
local NOT_ZERO = 0.1 -- degrees: at least one of the shots leaves the line by more than this (a Spread of 0 can't pass)

local function Guard(Body, After)
	SmokeKit.Guarded(Player, Body, function() GunKit.Unequip(Player) end, function()
		local Ok, Err = true, nil
		if After then Ok, Err = pcall(After) end
		GunKit.Clean()
		if not Ok then error(Err, 0) end
	end)
end

-- a Sykov shooter at the spot facing -Z, and its WCS character
local function Shooter()
	local S = GunKit.Shooter(Vector3.zero, GunKit.Spot() + AHEAD * 10, GUN)
	local WC = WCS.Character.GetCharacterFromInstance(S)
	assert(WC, "the shooter has a WCS character")
	return S, WC
end

return {
	-- the windup is readable: NpcShot.Startup (0.35 s) from "Startup" to "Active", not the shot's own 0.12
	WindupIsReadable = function(T)
		Guard(function()
			local S, WC = Shooter()
			local Target = GunKit.Dummy(AHEAD * DIST, "GunKit_Target")
			GunKit.Settle()
			-- A shot's Active phase lasts no time at all (its Strike, WeaponManager.Fire, runs at once and Recovery is set
			-- in the same step), and attribute signals are deferred: a handler reads "Recovery" by then. So the end of the
			-- windup is the first change that leaves "Startup", and the shot itself (LastShotAt) shows it went Active.
			S:SetAttribute("LastShotAt", nil)
			local StartAt, ActiveAt = nil, nil
			local Conn = S:GetAttributeChangedSignal("CombatState"):Connect(function()
				local State = S:GetAttribute("CombatState")
				if State == "Startup" and not StartAt then StartAt = os.clock()
				elseif State ~= "Startup" and StartAt and not ActiveAt then ActiveAt = os.clock() end
			end)
			EnemyService.GunShot(S, WC, Target, 1)
			Conn:Disconnect()
			T.True(StartAt ~= nil, "the shot had a Startup")
			T.True(ActiveAt ~= nil, "the shot left Startup")
			T.True(S:GetAttribute("LastShotAt") ~= nil, "the shot fired (it went Active)")
			if not (StartAt and ActiveAt) then return end
			T.Near(ActiveAt - StartAt, WINDUP, WINDUP_EPS, "seconds from Startup to Active")
		end)
	end,

	-- a target standing on a ledge is hit: the shot aims at its centre, not along the shooter's level look
	HitsATargetAbove = function(T)
		local Npc = Tuning.Weapons.Guns.NpcShot
		local Was = Npc.Spread
		Guard(function()
			Npc.Spread = 0 -- (Play only, put back by After) the shot goes exactly along the line
			local S, WC = Shooter()
			local Spot = GunKit.Spot()
			SmokeKit.TempPart({
				Name = "GunNpc_Ledge",
				Size = Vector3.new(LEDGE_FOOT, LEDGE, LEDGE_FOOT),
				CFrame = CFrame.new(Spot + AHEAD * DIST + Vector3.new(0, LEDGE / 2, 0)),
				Material = Enum.Material.Concrete,
			})
			local Target = GunKit.Dummy(AHEAD * DIST + Vector3.new(0, LEDGE, 0), "GunKit_Above")
			GunKit.Settle()
			S:SetAttribute("LastShotResult", nil)
			local Health = Target.Humanoid.Health
			local _, Results = EnemyService.GunShot(S, WC, Target, 1)
			T.Eq(S:GetAttribute("LastShotResult"), "Hit", "LastShotResult at a target on a " .. LEDGE .. "-stud ledge")
			T.Eq(Results and Results[1] and Results[1].Victim, Target, "the shot's victim")
			T.True(Target.Humanoid.Health < Health, "the target lost Health")
		end, function()
			Npc.Spread = Was
		end)
	end,

	-- 30 shots' aims each stay within NpcShot.Spread per axis of the line to the target, and they do spread
	SpreadStaysInCone = function(T)
		local SetAim = WeaponManager.SetAim
		local Dirs = {}
		local S = nil
		Guard(function()
			local WC
			S, WC = Shooter()
			local Target = GunKit.Dummy(AHEAD * DIST, "GunKit_Target")
			GunKit.Settle()
			-- (Play only, removed by After) records the shooter's aims; everything else goes straight through
			WeaponManager.SetAim = function(Character, Dir)
				if Character == S then table.insert(Dirs, Dir) end
				return SetAim(Character, Dir)
			end
			for I = 1, SPREAD_SHOTS do
				EnemyService.GunShot(S, WC, Target, (I - 1) % 4 + 1)
			end
			T.Eq(#Dirs, SPREAD_SHOTS, "aims set by " .. SPREAD_SHOTS .. " shots")
			local Frame = CFrame.lookAt(Vector3.zero, LINE)
			local Widest = 0
			for I, D in ipairs(Dirs) do
				local L = Frame:VectorToObjectSpace(D.Unit)
				local Yaw = math.deg(math.asin(math.clamp(-L.X, -1, 1)))
				local Pitch = math.deg(math.atan2(L.Y, -L.Z))
				T.True(math.abs(Yaw) <= SPREAD + SPREAD_EPS, ("shot %d: yaw %.3f degrees off the line"):format(I, Yaw))
				T.True(math.abs(Pitch) <= SPREAD + SPREAD_EPS, ("shot %d: pitch %.3f degrees off the line"):format(I, Pitch))
				Widest = math.max(Widest, math.deg(math.acos(math.clamp(D.Unit:Dot(LINE), -1, 1))))
			end
			T.True(Widest > NOT_ZERO, ("the widest shot is %.3f degrees off the line (control: the shots spread)"):format(Widest))
		end, function()
			WeaponManager.SetAim = SetAim
		end)
	end,
}

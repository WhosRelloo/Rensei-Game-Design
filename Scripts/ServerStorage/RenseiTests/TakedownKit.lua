-- TakedownKit (assassinations Task 4, 2026-10-27): the takedown suites' shared fixture (Play_Takedown, which Tasks 5-9
-- extend). Required, never copied. Run in the game VM (LMRunSuite), never in Edit. It builds on SmokeKit (pre-flight
-- Rulings R5 and D5): SmokeKit's TempPart (the floor and walls), Guarded (the clean-up and the character put back) and
-- the perception helpers moved there from Play_Stealth (Run, SpawnEnemy, RemoveEnemy, SweepEnemies). Nothing here
-- re-implements them.
--   * Kit.Player(): the test player (the first in the server), whose character every helper moves and restores.
--   * Kit.Spot(): the test spot, the top centre of a Play-only floor high above the map (Ruling R4: Task 1's survey spots
--     are in town, where Glimpse, Call and fleeing townsfolk would reach real NPCs). X/Z are Task 1's survey spot for
--     this place (survey_ye.json / survey_foundry.json, 2026-10-27); Y is SPOT_Y. Guard lays the floor there; outside
--     Guard there is none.
--   * Kit.Spawn(Type, At, Opts) -> Rig: EnemyService.Spawn from an unparented mark (EnemyType = Type), so it never
--     respawns; AIPassive, and Credited unless Opts.Credit (a takedown test of credit); its root anchored and the rig
--     standing at At (a CFrame on the floor: where it stands and which way it faces); then, once PerceptionService
--     tracks it (or after 2 s for a type it never tracks), reset to Unaware. Only inside Guard.
--   * Kit.Face(Rig, Dir): the rig turned, where it stands, to face Dir (level).
--   * Kit.PutPlayer(At): the player's character root anchored at At (a CFrame), velocity zeroed, 0.15 s to settle.
--   * Kit.PutInFront(Rig, Dist) / Kit.PutBehind(Rig, Dist, AngleFromBack): the player Dist studs from the rig's root,
--     straight ahead of it / behind it turned AngleFromBack degrees (default 0) off its back, facing it.
--   * Kit.Wall(At, Size): an anchored test part (SmokeKit.TempPart), removed when Guard ends.
--   * Kit.Run(Seconds): SmokeKit.Run (PerceptionService.Step(0.2) repeated; Guard holds SetAuto(false)).
--   * Kit.Guard(Body): saves the character's CombatMode, Crouching and Exposure (SmokeKit.Guarded saves its pivot and
--     Anchored); PerceptionService and LightService SetAuto(false); lays the floor; runs Body in a pcall; then Kit.Clean
--     and the put-back. Re-raises Body's error.
--   * Kit.Clean(): Guard's clean-up (Guard calls it; SmokeKit.Guarded then removes the parts and puts the character
--     back): a carry the case left dropped and any carry weld off the player's root (Task 6), every rig the kit made removed (and any other enemy left on the floor), TakingDown, TakedownReadyAt and
--     LastTakedownResult cleared on the character, the saved attributes restored, both loops SetAuto(true). (Task 7) A
--     crouch Kit.Crouch started is stopped; a takedown left running is waited out (its victim is gone, so it ends as an
--     interrupt), and TakedownService forgets the player's cooldown (Forget), so no case starts on the last one's.
--   * Kit.Crouch(On) (Task 7): the player crouches as CharacterHandler's crouch does (a WCS Stun stored in
--     AttackRunner.CrouchStuns, Crouching = true), or stands up again (only a crouch the kit started is stopped).
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local PS = require(SSS.PerceptionService)
local LS = require(SSS.LightService)
local SmokeKit = require(script.Parent.SmokeKit)
local DownedManager = require(game:GetService("ReplicatedStorage").Modules.Managers.DownedManager)
local Modules = game:GetService("ReplicatedStorage").Modules
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local CrouchStuns = require(Modules.Managers.AttackRunner).CrouchStuns

local Kit = {}

-- Task 1's survey spot X/Z by place (Art/Studio/Takedown/survey_*.json, 2026-10-27): Ye from Lindenmoor square's spawn,
-- Foundry from the Foundry spawn
local SURVEY = {
	[106992859583940] = Vector3.new(-32, 0, -700), -- Ye: (-32, 9, -700) on Lindenmoor's grass
	[109591196441030] = Vector3.new(-680, 0, 392), -- Foundry: (-680, 4, 392) on Foundry ground
}
local SPOT_Y = 3000 -- PROPOSAL (Ruling R4): above both maps (their tops are under y 430); GunKit's floor is at 2000, Play_Stealth's at 2500
local FLOOR = Vector3.new(160, 1, 160) -- PROPOSAL: room for rigs 60 studs apart (RaiseSearches) and the player
local SWEEP = 120 -- PROPOSAL: studs from the spot; Clean removes any enemy this near (a Spawn that threw half-way)
local SAVED = {"CombatMode", "Crouching", "Exposure"} -- the character attributes Guard puts back
local CLEARED = {"TakingDown", "TakedownReadyAt", "LastTakedownResult"} -- cleared after every case

local Made = {} -- the rigs Spawn made, until Clean
local Saved = nil -- the attributes Guard saved, while a Guard runs

function Kit.Player() return Players:GetPlayers()[1] end

function Kit.Spot()
	local XZ = SURVEY[game.PlaceId]
	assert(XZ, "TakedownKit: no survey spot for place " .. tostring(game.PlaceId))
	return Vector3.new(XZ.X, SPOT_Y, XZ.Z)
end

function Kit.Spawn(Type, At, Opts)
	Opts = Opts or {}
	assert(Saved ~= nil, "TakedownKit.Spawn runs inside Guard (its floor and its clean-up)")
	local Rig = SmokeKit.SpawnEnemy(Type, At.Position)
	table.insert(Made, Rig)
	Rig:SetAttribute("AIPassive", true)
	if not Opts.Credit then Rig:SetAttribute("Credited", true) end
	Rig.HumanoidRootPart.Anchored = true
	Rig:PivotTo(At + Vector3.new(0, 3, 0)) -- the root 3 studs above the floor, as Play_Stealth's Grunt stands
	local T0 = os.clock()
	while not PS.Tracks(Rig) and os.clock() - T0 < 2 do task.wait(0.05) end
	PS.Reset(Rig)
	return Rig
end

function Kit.Face(Rig, Dir)
	local Pos = Rig:GetPivot().Position
	Rig:PivotTo(CFrame.lookAt(Pos, Pos + Vector3.new(Dir.X, 0, Dir.Z)))
end

function Kit.PutPlayer(At)
	local C = Kit.Player().Character
	local Root = C.HumanoidRootPart
	Root.Anchored = true
	C:PivotTo(At)
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end

-- the player Dist studs from the rig's root along Dir (level), facing the rig
local function Around(Rig, Dir, Dist)
	local At = Rig.HumanoidRootPart.Position
	local Pos = At + Vector3.new(Dir.X, 0, Dir.Z).Unit * Dist
	Kit.PutPlayer(CFrame.lookAt(Pos, Vector3.new(At.X, Pos.Y, At.Z)))
end

function Kit.PutInFront(Rig, Dist)
	Around(Rig, Rig.HumanoidRootPart.CFrame.LookVector, Dist)
end

function Kit.PutBehind(Rig, Dist, AngleFromBack)
	local Back = -Rig.HumanoidRootPart.CFrame.LookVector
	Around(Rig, CFrame.Angles(0, math.rad(AngleFromBack or 0), 0):VectorToWorldSpace(Back), Dist)
end

function Kit.Wall(At, Size)
	return SmokeKit.TempPart({Name = "Takedown_Wall", Size = Size, CFrame = At})
end

Kit.Run = SmokeKit.Run

local KitCrouch = nil -- the crouch Stun Kit.Crouch started, until it stops it
function Kit.Crouch(On)
	local C = Kit.Player().Character
	local WC = WCS.Character.GetCharacterFromInstance(C)
	assert(WC, "the player has a WCS character")
	if On then
		if not CrouchStuns[WC] then
			local S = Stun.new(WC)
			S:Start()
			CrouchStuns[WC] = S
			KitCrouch = S
		end
		C:SetAttribute("Crouching", true)
	elseif KitCrouch then
		if CrouchStuns[WC] == KitCrouch then CrouchStuns[WC] = nil end
		pcall(function() KitCrouch:Stop() end)
		KitCrouch = nil
		C:SetAttribute("Crouching", nil)
	end
end

function Kit.Clean()
	Kit.Crouch(false)
	-- (Task 6) a case that failed mid-carry: set the body down first (the carrier's walk back), and no carry weld stays
	-- on the player's root
	local Char = Kit.Player().Character
	if Char:GetAttribute("Carrying") then pcall(DownedManager.Drop, Char) end
	for _, W in ipairs(Char.HumanoidRootPart:GetChildren()) do
		if W.Name == "DownedWeld" then W:Destroy() end
	end
	for _, Rig in ipairs(Made) do SmokeKit.RemoveEnemy(Rig) end
	table.clear(Made)
	SmokeKit.SweepEnemies(Kit.Spot(), SWEEP)
	-- (Task 7) a takedown a failed case left running ends once its victim is gone (an interrupt): wait for its release, so
	-- what it writes on the character is cleared below; then the next case starts off cooldown
	local T0 = os.clock()
	while Char:GetAttribute("TakingDown") and os.clock() - T0 < 2 do task.wait(0.05) end
	local TDS = SSS:FindFirstChild("TakedownService")
	if TDS then pcall(function() require(TDS).Forget(Kit.Player()) end) end
	local C = Kit.Player().Character
	for _, K in ipairs(CLEARED) do C:SetAttribute(K, nil) end
	if Saved then
		for _, K in ipairs(SAVED) do C:SetAttribute(K, Saved[K]) end
	end
	Saved = nil
	PS.SetAuto(true); LS.SetAuto(true)
end

function Kit.Guard(Body)
	local C = Kit.Player().Character
	SmokeKit.Guarded(Kit.Player(), Body, function()
		Saved = {}
		for _, K in ipairs(SAVED) do Saved[K] = C:GetAttribute(K) end
		PS.SetAuto(false); LS.SetAuto(false)
		SmokeKit.TempPart({Name = "Takedown_Floor", Size = FLOOR, CFrame = CFrame.new(Kit.Spot() - Vector3.new(0, FLOOR.Y / 2, 0))})
	end, Kit.Clean)
end

return Kit

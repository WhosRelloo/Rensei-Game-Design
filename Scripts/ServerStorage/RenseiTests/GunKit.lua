-- GunKit (gun rework Task 4, 2026-10-25): the test rigs every gun suite uses, in one module (the global "no duplicated
-- test logic" rule). Run in the game VM (LMRunSuite), never in Edit. Gun suites only.
--   * GunKit.Spot(): the test spot for this place. Neither place has a flat open spot (Task 1's survey, 2026-10-25), so
--     the spot is a Play-only flat floor (GunKit_Floor, a SmokeKit.TempPart) made the first time Spot() is called and
--     again after a Clean(), FLOOR_Y above the surveyed X / Z (Ruling 4b). Returns the point on the floor's top
--     centre. Errors in any place but Ye and Foundry.
--   * GunKit.Dummy(Offset, Name): an R6 clone of StarterPlayer.StarterCharacter standing on the floor at
--     Spot() + Offset (feet on the floor; the root is anchored; streamed Persistent), in World.Live,
--     Health = MaxHealth = 1000, no EnemyType, made fight-ready with EnemyService.MakeCombatant(Rig, 0) so
--     DamageManager doesn't call it IFramed. Returns the Model.
--   * GunKit.Shooter(Offset, LookAt, Item): a Dummy facing LookAt (a world point), CombatMode = true,
--     PhysicalMultiplier = 1, armed with WeaponManager.Give(Model, Item).
--   * GunKit.Shot(Shooter, Dir): WeaponManager.SetAim, then one Guns_Shot1 through WeaponManager.Fire with the held
--     gun's numbers (WeaponManager.Resolve). Returns Fire's results, and {[Victim] = Health before - after} for each
--     victim the kit made.
--   * GunKit.Unequip(Player) (Ruling 4c): Humanoid:UnequipTools() on the test player (the Tool goes to the Backpack;
--     it is never destroyed), then errors if a Tool is still in the character. A gun suite runs it before its cases.
--   * GunKit.Settle(): waits SETTLE seconds. A suite calls it after making its rigs and before the first hit: a new
--     Persistent rig reaches the client a little later than the hit effect a remote sends with it.
--   * GunKit.Clean(): Settle()s when it made any Model (the last hit's effects finish), destroys every Model the kit
--     made (its WCS character first), then SmokeKit.ClearTemp() (the floor goes too).
-- Every gun suite wraps its cases in SmokeKit.Guarded, with GunKit.Clean as After.
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmokeKit = require(script.Parent.SmokeKit)
local EnemyService = require(SSS.EnemyService)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local GunKit = {}

-- The surveyed X / Z of each place (Task 1's survey, 2026-10-25, Art/Studio/Guns/survey_*.json; no spot met the rules):
--   Ye: the best near miss, centre (-200, 6, 250) (Lindenmoor's west fields);
--   Foundry: no near miss; the map box's centre (1, 203, -316).
GunKit.SPOTS = {
	[106992859583940] = Vector3.new(-200, 0, 250), -- Ye
	[109591196441030] = Vector3.new(1, 0, -316), -- Foundry
}
GunKit.FLOOR_Y = 2000 -- PROPOSAL: the floor's centre height, far above both maps (their tops are under y 430)
GunKit.FLOOR_SIZE = Vector3.new(200, 1, 200) -- PROPOSAL
GunKit.HEALTH = 1000 -- PROPOSAL: a dummy outlives any one suite's shots
GunKit.SETTLE = 0.5 -- PROPOSAL: seconds Settle() waits (seen in Play 2026-10-25: without it a hit's deferred hitstop
-- and its client hit effect error on dummies just made or just destroyed)
local ROOT_UP = 3 -- an R6 root stands 3 studs over the ground (Task 1's survey: R6 extents min y -3)

local Made = {} -- the Models the kit made, until Clean
local Floor = nil

function GunKit.Spot()
	local XZ = GunKit.SPOTS[game.PlaceId]
	if not XZ then error("GunKit.Spot: no test spot for place " .. tostring(game.PlaceId), 2) end
	local Top = Vector3.new(XZ.X, GunKit.FLOOR_Y + GunKit.FLOOR_SIZE.Y / 2, XZ.Z)
	if not (Floor and Floor.Parent) then
		Floor = SmokeKit.TempPart({
			Name = "GunKit_Floor",
			Size = GunKit.FLOOR_SIZE,
			CFrame = CFrame.new(XZ.X, GunKit.FLOOR_Y, XZ.Z),
			Material = Enum.Material.Concrete,
		})
	end
	return Top
end

function GunKit.Dummy(Offset, Name)
	local Rig = game:GetService("StarterPlayer").StarterCharacter:Clone()
	local Link = Rig:FindFirstChildOfClass("PackageLink")
	if Link then Link:Destroy() end
	Rig.Name = Name or "GunKit_Dummy"
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	Humanoid.MaxHealth = GunKit.HEALTH
	Humanoid.Health = GunKit.HEALTH
	-- hit reactions play on it (EnemyService's BuildRig adds one the same way)
	if not Humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator", Humanoid) end
	Rig:SetAttribute("EnemyType", nil)
	Rig.HumanoidRootPart.Anchored = true
	-- the floor is far beyond the player's streaming radius: Persistent sends the rig to every client anyway, so client
	-- hit effects (and later client checks) find its parts
	Rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	Rig:PivotTo(CFrame.new(GunKit.Spot() + (Offset or Vector3.zero) + Vector3.new(0, ROOT_UP, 0)))
	Rig.Parent = workspace.World.Live
	table.insert(Made, Rig)
	EnemyService.MakeCombatant(Rig, 0)
	return Rig
end

function GunKit.Shooter(Offset, LookAt, Item)
	local Rig = GunKit.Dummy(Offset, "GunKit_Shooter")
	local At = Rig:GetPivot().Position
	local Flat = Vector3.new(LookAt.X, At.Y, LookAt.Z)
	if (Flat - At).Magnitude > 1e-3 then Rig:PivotTo(CFrame.lookAt(At, Flat)) end
	Rig:SetAttribute("CombatMode", true)
	Rig:SetAttribute("PhysicalMultiplier", 1)
	assert(WeaponManager.Give(Rig, Item), "GunKit.Shooter: no Tool for " .. tostring(Item))
	return Rig
end

function GunKit.Shot(Shooter, Dir)
	local Before = {}
	for _, M in ipairs(Made) do
		local H = M:FindFirstChildOfClass("Humanoid")
		if H then Before[M] = H.Health end
	end
	WeaponManager.SetAim(Shooter, Dir)
	local Results = WeaponManager.Fire(Shooter, "Guns_Shot1", WeaponManager.Resolve(Shooter, Tuning.Weapons.Guns.Shots[1]))
	local Lost = {}
	for _, R in ipairs(Results) do
		local H = R.Victim:FindFirstChildOfClass("Humanoid")
		local Was = Before[R.Victim]
		if H and Was then Lost[R.Victim] = Was - H.Health end
	end
	return Results, Lost
end

function GunKit.Unequip(Player)
	local C = Player.Character
	local Humanoid = C and C:FindFirstChildOfClass("Humanoid")
	assert(Humanoid, "GunKit.Unequip: the player has a character")
	Humanoid:UnequipTools()
	local Held = C:FindFirstChildOfClass("Tool")
	if Held then error("GunKit.Unequip: " .. Held.Name .. " is still in the character", 2) end
end

function GunKit.Settle()
	task.wait(GunKit.SETTLE)
end

function GunKit.Clean()
	if #Made > 0 then GunKit.Settle() end
	for _, M in ipairs(Made) do
		local WC = WCS.Character.GetCharacterFromInstance(M)
		if WC then WC:Destroy() end
		M:Destroy()
	end
	table.clear(Made)
	Floor = nil
	SmokeKit.ClearTemp()
end

return GunKit

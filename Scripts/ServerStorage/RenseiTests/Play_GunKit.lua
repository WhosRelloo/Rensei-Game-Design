-- Play_GunKit (gun rework Task 4, 2026-10-25): GunKit's own checks, in the Play VM (LMRunSuite). Every case runs in
-- SmokeKit.Guarded with GunKit.Clean as After, after GunKit.Unequip (Ruling 4c). The expected spots are this test's own
-- constants (Task 1's survey X / Z, 2026-10-25; the floor's top at 2000.5), never read from GunKit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
local DamageManager = require(ReplicatedStorage.Modules.Managers.DamageManager)
local Player = game.Players:GetPlayers()[1]

local EXPECT_SPOT = { -- worked by hand: survey X / Z; Y = the floor's centre 2000 + half its 1-stud height
	[106992859583940] = Vector3.new(-200, 2000.5, 250), -- Ye
	[109591196441030] = Vector3.new(1, 2000.5, -316), -- Foundry
}

local function Guard(Body)
	SmokeKit.Guarded(Player, Body, function() GunKit.Unequip(Player) end, GunKit.Clean)
end

return {
	DummyCanBeHit = function(T)
		Guard(function()
			local Dummy = GunKit.Dummy(Vector3.new(0, 0, -10), "GunKit_Target")
			local Shooter = GunKit.Shooter(Vector3.zero, Dummy:GetPivot().Position, "Revolver")
			GunKit.Settle()
			local Was = Dummy.Humanoid.Health
			T.Eq(DamageManager(Shooter, Dummy, SkillData.Guns_Shot1), "Hit", "the kit's dummy")
			T.True(Dummy.Humanoid.Health < Was, ("the dummy loses Health (%s -> %s)"):format(Was, Dummy.Humanoid.Health))
			-- control: a plain StarterCharacter clone, never made fight-ready, is IFramed
			local Plain = game:GetService("StarterPlayer").StarterCharacter:Clone()
			Plain.Name = "GunKit_PlainControl"
			if Plain:FindFirstChildOfClass("PackageLink") then Plain:FindFirstChildOfClass("PackageLink"):Destroy() end
			Plain.HumanoidRootPart.Anchored = true
			Plain:PivotTo(CFrame.new(GunKit.Spot() + Vector3.new(6, 3, -10)))
			Plain.Parent = workspace.World.Live
			local Ok, Res = pcall(DamageManager, Shooter, Plain, SkillData.Guns_Shot1)
			Plain:Destroy()
			T.True(Ok, "control: " .. tostring(Res))
			T.Eq(Res, "IFramed", "control: a plain clone with no MakeCombatant")
		end)
	end,

	CleanLeavesNothing = function(T)
		local Kept
		Guard(function()
			Kept = {GunKit.Dummy(Vector3.new(0, 0, -10)), GunKit.Shooter(Vector3.zero, Vector3.new(0, 0, -10), "Revolver")}
			for _, M in ipairs(Kept) do T.True(M:IsDescendantOf(workspace.World.Live), M.Name .. " is in World.Live first") end
		end)
		for _, M in ipairs(Kept) do
			T.True(not M:IsDescendantOf(workspace.World.Live), M.Name .. " is gone from World.Live")
			T.Eq(WCS.Character.GetCharacterFromInstance(M), nil, M.Name .. "'s WCS character")
		end
		T.Eq(workspace:FindFirstChild("GunKit_Floor"), nil, "the floor is gone")
	end,

	SpotIsThisPlace = function(T)
		local Want = EXPECT_SPOT[game.PlaceId]
		T.True(Want ~= nil, "this test knows place " .. tostring(game.PlaceId))
		Guard(function()
			local Spot = GunKit.Spot()
			T.Eq(Spot, Want, "Spot() for this place")
			local RP = RaycastParams.new()
			RP.FilterType = Enum.RaycastFilterType.Exclude
			RP.FilterDescendantsInstances = {workspace.World.Live}
			local Hit = workspace:Raycast(Spot + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), RP)
			T.True(Hit ~= nil, "a ray down from 20 over the spot meets ground")
			T.Near(Hit.Position.Y, Want.Y, 0.5, "the ground's height (" .. Hit.Instance:GetFullName() .. ")")
		end)
	end,
}

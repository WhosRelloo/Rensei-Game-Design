-- SwimKit (swim revamp Task 3, 2026-10-26): shared helpers for the swim tests (Play_Swim, the client checks).
-- Required, never copied (the plan's "no duplicated test logic").
--   SwimKit.Spots(PlaceId)          the test spots, HARD-CODED from Task 1's survey (Art/Studio/Swim/survey_*.json,
--                                   2026-10-26), never read from the water at test time. Each spot is the water's
--                                   surface point over a surveyed column, with the surveyed Depth.
--   SwimKit.Rig(At)                 an anchored R6 test rig (__swimtest_rig) with its head at At, in workspace. The
--                                   caller destroys it (SwimKit.Drop).
--   SwimKit.Drop(Rig)               destroys a rig and forgets it in SwimService / MovementState.
--   SwimKit.WithPlayerAt(Player, CF, Fn)  anchors the real character's root at CF, runs Fn, and ALWAYS puts back the
--                                   CFrame, Anchored, Breath / Drowning / Submerged (nil) and Combat Mode, even on error.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwimKit = {}

local YE, FOUNDRY = 106992859583940, 109591196441030

-- surveyed 2026-10-26: (x, surface top, z) of a column, and its depth (surface to bed)
local SPOTS = {
	[FOUNDRY] = {
		PondDeep = {At = Vector3.new(488, 3, -148), Depth = 9}, -- the cooling pond's centre (782 columns are 9 deep)
		PondEdge = {At = Vector3.new(424, 3, -148), Depth = 9}, -- one column in from the west bank (lip 1 stud)
	},
	[YE] = {
		MillPond = {At = Vector3.new(-112, 5.2, -552), Depth = 5.2}, -- surveyed top 5.19, bed 0 (Ground.Tops)
		GorgePool = {At = Vector3.new(224, 5.2, -552), Depth = 5.2}, -- bed 0 (Ground.Tops)
		Creek = {At = Vector3.new(-375, 5.2, -527), Depth = 4.2}, -- creek_west_water_0: top 5.2, bed 1 (too shallow to dive)
		Plunge = nil, -- Task 8 (the plunge hole) sets it
	},
}

function SwimKit.Spots(PlaceId)
	return SPOTS[PlaceId or game.PlaceId] or {}
end

-- the first spot of this place that a rig test uses (Foundry's deep pond, Ye's Mill Pond), or nil
function SwimKit.Main(PlaceId)
	local S = SwimKit.Spots(PlaceId)
	return S.PondDeep or S.MillPond
end

local function SwimService()
	return require(ServerScriptService:WaitForChild("SwimService", 10))
end

function SwimKit.Rig(At)
	local Rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	Rig.Name = "__swimtest_rig"
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	Root.Anchored = true
	Rig.Parent = workspace
	SwimKit.PutHead(Rig, At)
	return Rig
end

-- moves a rig so its head's centre is at At
function SwimKit.PutHead(Rig, At)
	local Head = Rig:FindFirstChild("Head")
	Rig:PivotTo(Rig:GetPivot() + (At - Head.Position))
end

function SwimKit.Drop(Rig)
	if not Rig then return end
	pcall(function()
		local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
		if MovementState.Get(Rig) == "Swim" then MovementState.SetSwim(Rig, false) end
	end)
	pcall(function() SwimService().Forget(Rig) end)
	Rig:Destroy()
end

function SwimKit.WithPlayerAt(Player, CF, Fn)
	local C = Player and Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root then error("SwimKit.WithPlayerAt: no character") end
	local Was, Anchored, Combat = Root.CFrame, Root.Anchored, C:GetAttribute("CombatMode") == true
	Root.Anchored = true
	Root.CFrame = CF
	local Res = table.pack(pcall(Fn, C))
	Root.CFrame = Was
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.Anchored = Anchored
	for _, A in {"Breath", "Drowning", "Submerged", "SwimSprint", "SwimSpeedStrikes"} do C:SetAttribute(A, nil) end
	pcall(function() SwimService().Forget(C) end)
	if (C:GetAttribute("CombatMode") == true) ~= Combat then
		pcall(function()
			local CombatMode = require(ServerScriptService.ServerHandler.Requests.CombatMode)
			CombatMode(Player, Combat)
		end)
	end
	if not Res[1] then error(Res[2], 0) end
	return table.unpack(Res, 2, Res.n)
end

return SwimKit

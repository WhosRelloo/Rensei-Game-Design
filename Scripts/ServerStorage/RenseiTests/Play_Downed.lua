-- Play_Downed (downed crawl side task, 2026-10-27): the knocked player's crawl, in the game VM (LMRunSuite, inside the
-- save snapshot / restore harness). Owner: "Yes, slow crawl": a knocked PLAYER crawls at TuningConfig.Downed.CrawlSpeed
-- (PROPOSAL 3) with Downed Idle / Downed Crawl; knocked enemies (and the assassinations' knockout) stay still; a
-- gripped or carried body doesn't crawl; recovering gives back exactly what the player had.
-- Fixture: the test player's character is knocked with a 60 s knock (attribute KnockedTime) and ALWAYS recovered and put
-- back (pivot, health, KnockedTime); dummies are StarterCharacter clones in World.Live, always destroyed.
-- The grip test cancels the grip by removing the gripper at once, so the finisher never completes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local Cfg = Tuning.Downed
local Player = Players:GetPlayers()[1]

local function WaitFor(Seconds, Fn)
	local T0 = os.clock()
	while os.clock() - T0 < Seconds do
		if Fn() then return true end
		task.wait(0.05)
	end
	return Fn()
end

local Made = {}
local function Dummy(Name, Offset, Anchored)
	local Root = Player.Character.HumanoidRootPart
	local Rig = StarterPlayer.StarterCharacter:Clone()
	local Link = Rig:FindFirstChildOfClass("PackageLink")
	if Link then Link:Destroy() end
	Rig.Name = Name
	local H = Rig:FindFirstChildOfClass("Humanoid")
	if not H:FindFirstChildOfClass("Animator") then Instance.new("Animator", H) end
	Rig:SetAttribute("EnemyType", nil)
	Rig.HumanoidRootPart.Anchored = Anchored ~= false
	Rig:PivotTo(Root.CFrame * CFrame.new(Offset or Vector3.new(0, 0, -8)))
	Rig.Parent = workspace.World.Live
	table.insert(Made, Rig)
	return Rig
end

-- knocks the test player's character (60 s), runs Fn(C, H, Was), and ALWAYS clears the downed attributes, recovers,
-- removes the dummies and puts the character back; errors are re-raised after the cleanup
local function Knocked(Fn)
	local C = Player and Player.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	assert(H and H.Health > 0 and not DownedManager.IsKnocked(C), "no standing test player")
	local Root = C.HumanoidRootPart
	local Was = {WS = H.WalkSpeed, JH = H.JumpHeight, Health = H.Health, KT = C:GetAttribute("KnockedTime"),
		Pivot = C:GetPivot(), SW = C:GetAttribute("SecondWindUsed")}
	C:SetAttribute("KnockedTime", 60)
	-- (Second Wind, a skill-tree keystone, would shorten the knock to 12 s: mark it used for the test)
	C:SetAttribute("SecondWindUsed", true)
	DownedManager.Knock(C)
	local Ok, Err = pcall(Fn, C, H, Was)
	for _, M in ipairs(Made) do pcall(function() if M:GetAttribute("Carrying") then DownedManager.Drop(M) end end) end
	for _, M in ipairs(Made) do M:Destroy() end
	table.clear(Made)
	C:SetAttribute("GrippedBy", nil)
	C:SetAttribute("CarriedBy", nil)
	if DownedManager.IsKnocked(C) then DownedManager.Recover(C) end
	C:SetAttribute("KnockedTime", Was.KT)
	C:SetAttribute("SecondWindUsed", Was.SW)
	C:SetAttribute("SecondWindActive", nil)
	H.Health = Was.Health
	Root.AssemblyLinearVelocity = Vector3.zero
	C:PivotTo(Was.Pivot)
	if not Ok then error(Err, 0) end
end

return {
	-- a knocked player crawls: WalkSpeed = CrawlSpeed, no jump, and the watch and MoverManager keep it there
	KnockedPlayerCrawls = function(T)
		Knocked(function(C, H)
			T.Eq(C:GetAttribute("Knocked"), true, "knocked")
			T.Eq(Cfg.CrawlSpeed, 3, "CrawlSpeed (PROPOSAL)")
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "knocked player's WalkSpeed")
			T.Eq(H.JumpHeight, 0, "no jump")
			T.True(DownedManager.CanCrawl(C), "CanCrawl")
			task.wait(0.35)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "after a few watch checks")
			-- a movement change ending mid-knock (a hit's slow, an attack) hands back the crawl, not 0 or a walk
			MoverManager.Movement(C, {WS = 9, JH = 0, D = 0.1})
			task.wait(0.4)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "after MoverManager's expiry")
			-- another writer is undone by the watch
			H.WalkSpeed = 16
			task.wait(0.3)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "a stray write is undone")
		end)
	end,

	-- a knocked enemy (the assassinations' knockout uses the same knock) stays at 0
	KnockedEnemyStill = function(T)
		local Rig = Dummy("Downed_TestEnemy", Vector3.new(0, 0, -10))
		local H = Rig:FindFirstChildOfClass("Humanoid")
		Rig:SetAttribute("Knockable", true)
		Rig:SetAttribute("KnockedTime", 60)
		local Ok, Err = pcall(function()
			DownedManager.Knock(Rig)
			T.Eq(Rig:GetAttribute("Knocked"), true, "enemy knocked")
			T.Eq(H.WalkSpeed, 0, "knocked enemy's WalkSpeed")
			T.Eq(DownedManager.CanCrawl(Rig), false, "an enemy can't crawl")
			T.Eq(DownedManager.KnockedSpeed(Rig), 0)
			task.wait(0.35)
			T.Eq(H.WalkSpeed, 0, "still 0")
			DownedManager.Recover(Rig)
			T.Eq(Rig:GetAttribute("Knocked"), nil, "enemy up")
			T.Near(H.WalkSpeed, StarterPlayer.StarterCharacter.Humanoid.WalkSpeed, 1e-3, "enemy walk back")
		end)
		Rig:Destroy()
		table.clear(Made)
		if not Ok then error(Err, 0) end
	end,

	-- carried: WalkSpeed 0 as before (the carry's PlatformStand weld); set down, the crawl comes back
	CarriedNoCrawl = function(T)
		Knocked(function(C, H)
			local Carrier = Dummy("Downed_TestCarrier", Vector3.new(0, 0, -3))
			T.True(DownedManager.Carry(Carrier, C), "carry started")
			T.Eq(C:GetAttribute("CarriedBy"), Carrier.Name)
			T.Eq(H.WalkSpeed, 0, "carried: 0")
			T.Eq(DownedManager.CanCrawl(C), false)
			task.wait(0.35)
			T.Eq(H.WalkSpeed, 0, "carried: still 0 after watch checks")
			T.Near(Carrier.Humanoid.WalkSpeed, Cfg.CarryWalkSpeed, 1e-3, "the carrier's lock as before")
			-- the carry weld puts the body at CarryOffset (over the left shoulder), not on the carrier's own root
			local Rel = Carrier.HumanoidRootPart.CFrame:PointToObjectSpace(C.HumanoidRootPart.Position)
			T.True((Rel - Cfg.CarryOffset.Position).Magnitude < 0.05, "carried root at CarryOffset: " .. tostring(Rel))
			DownedManager.Drop(Carrier)
			T.Eq(C:GetAttribute("CarriedBy"), nil)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "set down: crawl again")
		end)
	end,

	-- gripped: WalkSpeed 0 the moment the grip starts (the gripper's grip stays as before); a cancelled grip gives the
	-- crawl back. (The gripper is removed at once, so the finisher never completes.)
	GrippedNoCrawl = function(T)
		Knocked(function(C, H)
			local Gripper = Dummy("Downed_TestGripper", Vector3.new(0, 0, -3))
			Gripper:SetAttribute("GripStyle", "Stomp") -- stands over the body (no weld)
			task.spawn(DownedManager.Grip, Gripper, C)
			T.True(WaitFor(1, function() return C:GetAttribute("GrippedBy") == Gripper.Name end), "grip started")
			T.Eq(H.WalkSpeed, 0, "gripped: 0")
			T.Eq(Gripper.Humanoid.WalkSpeed, 0, "the gripper's lock as before")
			task.wait(0.25)
			T.Eq(H.WalkSpeed, 0, "gripped: still 0")
			Gripper:Destroy()
			T.True(WaitFor(1, function() return C:GetAttribute("GrippedBy") == nil end), "grip cancelled")
			T.True(H.Health > 0 and DownedManager.IsKnocked(C), "still alive and knocked")
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "crawl again")
		end)
	end,

	-- up again: exactly the speed and jump the player had, the watch gone
	RecoverRestores = function(T)
		local H = Player.Character:FindFirstChildOfClass("Humanoid")
		local WS, JH = H.WalkSpeed, H.JumpHeight
		Knocked(function(C)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3)
			DownedManager.Recover(C)
			T.Eq(C:GetAttribute("Knocked"), nil, "up")
			T.Eq(C:GetAttribute("KnockedUntil"), nil)
			T.Near(H.WalkSpeed, WS, 1e-3, "walk speed back")
			T.Near(H.JumpHeight, JH, 1e-3, "jump back")
			task.wait(0.35)
			T.Near(H.WalkSpeed, WS, 1e-3, "the watch has stopped")
		end)
	end,

	-- deep water: a knocked body isn't swimming, so it floats still instead of paddling across at crawl speed
	DeepWaterStill = function(T)
		local Kit = game:GetService("ServerStorage").RenseiTests:FindFirstChild("SwimKit")
		local Spot = Kit and require(Kit).Main()
		if not Spot then return end -- (no surveyed deep water in this place)
		local SwimKit = require(Kit)
		Knocked(function(C, H)
			SwimKit.WithPlayerAt(Player, CFrame.new(Spot.At - Vector3.new(0, 2, 0)), function()
				task.wait(0.4)
				T.Eq(H.WalkSpeed, 0, "knocked in deep water: still")
			end)
			task.wait(0.4)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "out of the water: crawl again")
		end)
	end,

	-- no escape by train or road: the station's Held (departure, boarding) and the road's HELD list refuse a knock
	HeldRefusesTravel = function(T)
		local SS = ServerScriptService:FindFirstChild("StationService")
		if not SS then return end -- (a place with no station)
		local StationService = require(SS)
		Knocked(function(C)
			T.Eq(StationService.Held(C), true, "StationService.Held while knocked")
		end)
		T.Eq(StationService.Held(Player.Character), false, "standing again")
	end,
}

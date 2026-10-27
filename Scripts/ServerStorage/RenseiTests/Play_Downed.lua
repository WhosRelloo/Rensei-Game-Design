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
			-- a server-side write by another system (as Block's end on the server) is undone by the watch. (Client-side
			-- writes don't reach the server; the crouch's is guarded in ClientHandler.Crouch.)
			H.WalkSpeed = 16
			task.wait(0.3)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "a server-side stray write is undone")
			T.Eq(C:GetAttribute("KnockedStill"), nil, "free to crawl: not held still")
		end)
	end,

	-- fix round 1: the watch clamps the crawl's distance. A crawl-speed move (3 studs/s) is left alone; a 10-stud jump
	-- across the ground in one tick (as a teleport or speed exploit would make) is put back at the last allowed point.
	CrawlClamp = function(T)
		Knocked(function(C)
			local Root = C.HumanoidRootPart
			local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.2) -- past the knock's grace
			local Start = Root.Position
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			-- a normal crawl: 0.3 studs every 0.1 s for 1 s (3 studs/s), along the root's own back (open ground behind)
			local Back = -Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			Back = Back.Magnitude > 1e-3 and Back.Unit or Vector3.new(1, 0, 0)
			for _ = 1, 10 do
				Root.CFrame += Back * 0.3
				task.wait(0.1)
			end
			task.wait(0.2)
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "a crawl-speed move isn't clamped")
			T.True(math.abs(Flat(Root.Position - Start) - 3) < 0.6, "the crawl kept its 3 studs (" .. Flat(Root.Position - Start) .. ")")
			-- a 10-stud jump in one tick (2 studs up too): put back at the last allowed point, height included (fix round 2)
			local Before = Root.Position
			Root.CFrame += Back * 10 + Vector3.new(0, 2, 0)
			task.wait(0.35)
			T.True(Flat(Root.Position - Before) < 1, "a 10-stud jump is undone (" .. Flat(Root.Position - Before) .. " studs off)")
			T.True(math.abs(Root.Position.Y - Before.Y) < 1, "and its height too (" .. (Root.Position.Y - Before.Y) .. ")")
			T.True((C:GetAttribute("CrawlClamped") or 0) > Clamped, "counted as clamped")
		end)
	end,

	-- fix round 2: a deliberate server move (StationService's watchdog, a road's arrival, an admin bring...) calls
	-- DownedManager.RebaseCrawl, and the knocked player stays where it was put
	RebasedMoveStays = function(T)
		Knocked(function(C)
			local Root = C.HumanoidRootPart
			local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.2)
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			local Back = -Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			Back = Back.Magnitude > 1e-3 and Back.Unit or Vector3.new(1, 0, 0)
			local To = Root.Position + Back * 10
			C:PivotTo(C:GetPivot() + Back * 10)
			DownedManager.RebaseCrawl(C)
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.4) -- (past the rebase's own grace: the clamp is on again)
			T.True(Flat(Root.Position - To) < 1, "stays where the server put it (" .. Flat(Root.Position - To) .. " off)")
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "not clamped")
		end)
	end,

	-- fix round 3: a rebase pins the clamp to the server's spot. A far move inside the rebase's grace without a new rebase
	-- (as a client riding the grace would make) is snapped back to that spot, and the snap isn't counted (it is also how
	-- the owning client's stale echo after a server move is handled)
	RebaseGraceSnapsBack = function(T)
		Knocked(function(C)
			local Root = C.HumanoidRootPart
			local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.2)
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			local Back = -Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			Back = Back.Magnitude > 1e-3 and Back.Unit or Vector3.new(1, 0, 0)
			C:PivotTo(C:GetPivot() + Back * 6)
			DownedManager.RebaseCrawl(C)
			local Spot = Root.Position
			task.wait(0.05)
			C:PivotTo(C:GetPivot() + Back * 10) -- inside the grace, no rebase
			task.wait(0.35)
			T.True(Flat(Root.Position - Spot) < 1, "snapped back to the rebased spot (" .. Flat(Root.Position - Spot) .. " off)")
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "the grace snap isn't counted")
		end)
	end,

	-- assassinations Task 6 (the side task's last re-review): the knock's own grace (CrawlClampGrace, for momentum) no
	-- longer follows the client. The clamp is pinned at the knock point: a move within the fastest legitimate speed (the
	-- dash's 110 studs/s) x the time since the knock is kept, a farther one is snapped back to the knock point and counted.
	KnockGraceSnapsBack = function(T)
		local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
		local function BackOf(Root)
			local Back = -Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			return Back.Magnitude > 1e-3 and Back.Unit or Vector3.new(1, 0, 0)
		end
		-- control: sprint momentum (24 studs/s, ClientHandler.Run) for 0.4 s inside the grace is kept
		Knocked(function(C)
			local Root = C.HumanoidRootPart
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			local Back, From = BackOf(Root), Root.Position
			for _ = 1, 4 do
				Root.CFrame += Back * 2.4
				task.wait(0.1)
			end
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.3)
			T.True(math.abs(Flat(Root.Position - From) - 9.6) < 1, "sprint momentum kept (" .. Flat(Root.Position - From) .. " of 9.6)")
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "momentum isn't clamped")
		end)
		-- a 100-stud teleport at once (no dash goes 100 studs in a tick): back at the knock point
		Knocked(function(C)
			local Root = C.HumanoidRootPart
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			local KnockAt = Root.Position
			Root.CFrame += BackOf(Root) * 100
			task.wait(0.35)
			T.True(Flat(Root.Position - KnockAt) < 1, "snapped back to the knock point (" .. Flat(Root.Position - KnockAt) .. " off)")
			T.True((C:GetAttribute("CrawlClamped") or 0) > Clamped, "counted as clamped")
		end)
	end,

	-- fix round 2: a knocked player in a seat, or welded into another assembly (a latch), is moved by that, not clamped
	SeatedOrWeldedNotClamped = function(T)
		Knocked(function(C, H)
			local Root = C.HumanoidRootPart
			local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
			task.wait((Cfg.CrawlClampGrace or 0.5) + 0.2)
			local Clamped = C:GetAttribute("CrawlClamped") or 0
			local Back = -Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			Back = Back.Magnitude > 1e-3 and Back.Unit or Vector3.new(1, 0, 0)
			-- welded into a heavier assembly whose root is another part, which then moves 10 studs
			local Body = Instance.new("Part")
			Body.Name = "Downed_TestLatch"
			Body.Size = Vector3.new(4, 1, 4)
			Body.CanCollide = false
			Body.RootPriority = 127
			Body.CFrame = Root.CFrame
			Body.Parent = workspace
			local W = Instance.new("WeldConstraint")
			W.Part0, W.Part1 = Body, Root
			W.Parent = Body
			local Ok, Err = pcall(function()
				task.wait(0.15)
				T.True(Root.AssemblyRootPart ~= Root, "welded: the assembly's root is the latch")
				local To = Root.Position + Back * 10
				Body.CFrame += Back * 10
				task.wait(0.35)
				T.True(Flat(Root.Position - To) < 1.5, "the latch moved it (" .. Flat(Root.Position - To) .. " off)")
			end)
			Body:Destroy()
			if not Ok then error(Err, 0) end
			task.wait(0.35)
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "welded: not clamped, nor after the release")
			-- seated: an anchored seat 8 studs away
			local Seat = Instance.new("Seat")
			Seat.Name = "Downed_TestSeat"
			Seat.Anchored = true
			Seat.Size = Vector3.new(2, 1, 2)
			Seat.CFrame = CFrame.new(Root.Position + Back * 8 - Vector3.new(0, 2, 0))
			Seat.Parent = workspace
			local Ok2, Err2 = pcall(function()
				Seat:Sit(H)
				task.wait(0.4)
				T.True(H.SeatPart == Seat, "seated")
				T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "seated: not clamped")
			end)
			Seat:Destroy()
			if not Ok2 then error(Err2, 0) end
			task.wait(0.35)
			T.Eq(C:GetAttribute("CrawlClamped") or 0, Clamped, "off the seat: not clamped")
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
			T.Eq(C:GetAttribute("KnockedStill"), true, "carried: held still (KnockedSpeed reads 0 on the client too)")
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
			T.Eq(C:GetAttribute("KnockedStill"), nil, "set down: not held")
			task.wait(0.3)
			T.Eq(C:GetAttribute("CrawlClamped"), nil, "being set down in front isn't clamped (Drop rebases)")
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
			T.Eq(C:GetAttribute("KnockedStill"), true, "gripped: held still")
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
			T.Eq(C:GetAttribute("KnockedStill"), nil)
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
			local Was = C.HumanoidRootPart.Position
			DownedManager.RebaseCrawl(C) -- (fix round 2: the kit is about to move the knocked player on purpose)
			SwimKit.WithPlayerAt(Player, CFrame.new(Spot.At - Vector3.new(0, 2, 0)), function()
				task.wait(0.4)
				T.Eq(H.WalkSpeed, 0, "knocked in deep water: still")
				-- fix round 1: the client's KnockedSpeed (MoverManager's hand-back, the crouch guard) reads 0 here too
				T.Eq(C:GetAttribute("KnockedStill"), true, "KnockedStill in deep water")
				T.Eq(DownedManager.KnockedSpeed(C), 0, "KnockedSpeed in deep water")
			end)
			DownedManager.RebaseCrawl(C) -- (the kit moved the knocked player on purpose)
			task.wait(0.4)
			T.Near(H.WalkSpeed, Cfg.CrawlSpeed, 1e-3, "out of the water: crawl again")
			T.Eq(C:GetAttribute("KnockedStill"), nil, "out of the water: not held")
			T.True((C.HumanoidRootPart.Position - Was).Magnitude < 1, "put back where it was, not clamped into the water")
		end)
	end,

	-- no escape by train: the station's Held (boarding and departure) refuses a knock. (The road's threshold refuses one
	-- too, through RoadService's local Unfit / HELD list; that is checked by reading the code, not here: Unfit isn't
	-- reachable from a test.)
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

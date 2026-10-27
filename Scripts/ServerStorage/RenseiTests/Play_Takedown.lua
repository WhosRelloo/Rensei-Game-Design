-- Play_Takedown (assassinations Task 4, 2026-10-27): takedowns inside the game VM (LMRunSuite). Every case runs in
-- TakedownKit.Guard on the kit's own floor high above the map, with rigs it spawned itself (never a world enemy, a
-- townsperson's real rig or the player), perception stepped by hand. Tasks 5-9 add their cases here.
-- Task 4: perception about takedowns -- a rig being taken down perceives nothing (Update, Hear, Perceived: pre-flight
-- R14); Glimpse, the one quick look every NPC takes at an attack; Raise, an Alert search at a spot with nobody to fight.
-- Task 5: bodies -- an enemy finds a registered body by sight (one ray, the tick's budget; light counts; under water
-- x0.3, pre-flight R7) and searches there, once per body; a takedown's corpse stays (Takedown.BodySeconds, not 4 s).
-- Task 6: DownedManager -- Knock takes an optional length; V carries a takedown's dead body (pre-flight R6, spec §18.1),
-- B never grips one, and a body removed mid-carry is dropped cleanly; Lock / Attach / Detach are shared (R16 / D3).
local SSS = game.ServerScriptService
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local PS = require(SSS.PerceptionService)
local LS = require(SSS.LightService)
local WorldClock = require(SSS.WorldClock) -- the clock moves, so the light cases hold it (as Play_Stealth does)
local Lighting = game:GetService("Lighting")
local Kit = require(script.Parent.TakedownKit)
local Player = Kit.Player()
local C = Player.Character

-- a CFrame on the kit's floor X / Z studs from the spot, facing -Z
local function At(X, Z)
	local Pos = Kit.Spot() + Vector3.new(X, 0, Z)
	return CFrame.lookAt(Pos, Pos + Vector3.new(0, 0, -1))
end

local function Has(List, Rig)
	for _, X in ipairs(List) do
		if X == Rig or (type(X) == "table" and X.Rig == Rig) then return true end
	end
	return false
end

-- Glimpse with the function checked first, so a missing one fails as such
local function Glimpse(Except)
	assert(type(PS.Glimpse) == "function", "PerceptionService.Glimpse exists")
	return PS.Glimpse(Player, Except)
end
local function Raise(Rig, Where)
	assert(type(PS.Raise) == "function", "PerceptionService.Raise exists")
	PS.Raise(Rig, Where)
end

-- ===== Task 5: bodies =====
-- where the player waits during a body case: 60 studs off on the floor, beyond a Grunt's 30-stud sight and outside
-- every cone the cases use, but within the 80 studs that keep the NPCs updating
local AWAY = At(60, 10) + Vector3.new(0, 3, 0)

-- the clock held at Hour while Body runs (Body may move it on), then put back as it was
local function AtHour(Hour, Body)
	local WasHeld = WorldClock.IsHeld() and Lighting.ClockTime
	WorldClock.Hold(Hour)
	local Ok, Err = pcall(Body)
	if WasHeld then WorldClock.Hold(WasHeld) else WorldClock.Release() end
	if not Ok then error(Err, 0) end
end

local function AddBody(Model, Info)
	assert(type(PS.AddBody) == "function", "PerceptionService.AddBody exists")
	PS.AddBody(Model, Info)
	return PS.Bodies[Model]
end

-- a kit Grunt at (X, Z) killed by the test as a takedown would leave it (TakenDownBy set), given 1 s to fall, then
-- registered as a "Dead" body. Returns the body and its Info.
local function DeadBody(X, Z)
	local Body = Kit.Spawn("Grunt", At(X, Z))
	Body:SetAttribute("TakenDownBy", Player.Name)
	Body.Humanoid.Health = 0
	task.wait(1)
	return Body, AddBody(Body, {Kind = "Dead", By = Player})
end

local function TorsoOf(Body) return Body:FindFirstChild("Torso") or Body:FindFirstChild("UpperTorso") or Body.HumanoidRootPart end

-- Body(Got) with a BodyFound listener that collects {Body, Finder, Info}; the listener comes out afterwards
local function Listen(Body)
	assert(type(PS.BodyFound) == "table", "PerceptionService.BodyFound exists")
	local Got = {}
	local function L(B, Finder, Info) table.insert(Got, {Body = B, Finder = Finder, Info = Info}) end
	table.insert(PS.BodyFound, L)
	local Ok, Err = pcall(Body, Got)
	local I = table.find(PS.BodyFound, L)
	if I then table.remove(PS.BodyFound, I) end
	if not Ok then error(Err, 0) end
end

-- perception stepped 0.2 s at a time until the body is found: the seconds it took, or nil within Max
local function TimeToFind(Info, Max)
	local Took = 0
	while not Info.Found and Took < Max - 1e-6 do
		Kit.Run(0.2)
		Took += 0.2
	end
	return Info.Found and Took or nil
end

-- terrain water over the kit spot: 16 x 8 x 16 on the 4-stud grid (the survey X / Z are multiples of 4), from the
-- floor's top up; On = false clears it
local function Water(On)
	workspace.Terrain:FillBlock(CFrame.new(Kit.Spot() + Vector3.new(0, 4, 0)), Vector3.new(16, 8, 16),
		On and Enum.Material.Water or Enum.Material.Air)
end

-- ===== Task 6: carrying =====
local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
-- the player 4 studs behind the rig at the spot (within CarryRange / GripRange 6), facing it (-Z)
local NEAR = At(0, 4) + Vector3.new(0, 3, 0)
-- the weld a carry leaves on the carrier's root (DownedManager's Attach names it)
local function CarryWeld() return C.HumanoidRootPart:FindFirstChild("DownedWeld") end
-- a kit rig lies free like a real one (Kit.Spawn anchors its root)
local function Free(Rig) Rig.HumanoidRootPart.Anchored = false return Rig end

return {
	SkipWhileTakenDown = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			C:SetAttribute("Exposure", 1)
			Rig:SetAttribute("TakenDownBy", Player.Name)
			Kit.Run(2)
			T.Eq(PS.Awareness(Rig, Player), 0, "taken down: notices nothing at 8 studs in the open")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "taken down: still Unaware")
			Rig:SetAttribute("TakenDownBy", nil)
			Kit.Run(2)
			T.True(PS.Awareness(Rig, Player) > 0, "control: free again, it notices the player")
		end)
	end,
	-- (pre-flight R14) the victim neither hears its own choke nor witnesses its own takedown
	TakenDownHearsNothing = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Sound = Rig.Head.Position + Vector3.new(6, 0, 0)
			Rig:SetAttribute("TakenDownBy", Player.Name)
			T.Eq(PS.Hear(Sound, 12, nil), 0, "taken down: hears nothing at 6 of 12")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "taken down: not sent to look")
			Rig:SetAttribute("TakenDownBy", nil)
			T.True(PS.Hear(Sound, 12, nil) >= 1 and PS.PhaseOf(Rig) == "Suspicious", "control: free, it hears it")
		end)
	end,
	TakenDownWitnessesNothing = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			PS.Alarm(Rig, Player) -- it has just seen the player
			Rig:SetAttribute("TakenDownBy", Player.Name)
			T.True(not Has(PS.Perceived(Player), Rig), "taken down: not a witness")
			Rig:SetAttribute("TakenDownBy", nil)
			T.True(Has(PS.Perceived(Player), Rig), "control: free, it is a witness")
		end)
	end,
	GlimpseFront = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			local Seen = Glimpse(nil)
			T.True(Has(Seen, Rig), "facing the player at 8: it sees the attack")
			T.Eq(PS.PhaseOf(Rig), "Alert", "a combat NPC that sees it is alarmed")
			T.Eq(PS.Target(Rig), C, "and fights the player")
		end)
	end,
	GlimpseBehind = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			Kit.Face(Rig, Vector3.new(0, 0, 1)) -- turned away from the player
			local Seen = Glimpse(nil)
			T.True(not Has(Seen, Rig), "turned away: it doesn't see")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	GlimpseWall = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			-- a 1 x 12 x 12 wall halfway, standing on the floor, its 1-stud side along the line between them
			local Mid = Kit.Spot() + Vector3.new(0, 6, -4)
			Kit.Wall(CFrame.lookAt(Mid, Mid + Vector3.new(0, 0, -1)) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1, 12, 12))
			local Seen = Glimpse(nil)
			T.True(not Has(Seen, Rig), "a wall between: it doesn't see")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	GlimpseExcept = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			local Seen = Glimpse(Rig)
			T.True(not Has(Seen, Rig), "the excepted rig (the victim) takes no look")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	RaiseSearches = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Near = Kit.Spawn("Grunt", At(0, 30)) -- inside the 40-stud call
			local Far = Kit.Spawn("Grunt", At(0, 60)) -- outside it
			local Where = Kit.Spot() + Vector3.new(10, 0, 0)
			Raise(Rig, Where)
			T.Eq(PS.PhaseOf(Rig), "Alert", "raised: Alert")
			T.Eq(PS.Target(Rig), nil, "nobody to fight")
			local Goal = PS.Goal(Rig)
			T.True(Goal ~= nil and (Goal - Where).Magnitude <= 20, "searches around the spot: " .. tostring(Goal))
			T.Eq(PS.PhaseOf(Near), "Suspicious", "a Grunt 30 studs off is called in")
			local NearGoal = PS.Goal(Near)
			T.True(NearGoal ~= nil and (NearGoal - Where).Magnitude < 0.01, "and comes to look at the spot: " .. tostring(NearGoal))
			T.Eq(PS.PhaseOf(Far), "Unaware", "a Grunt 60 studs off is not")
		end)
	end,
	RaiseThenSees = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Raise(Rig, Kit.Spot() + Vector3.new(10, 0, 0))
			Kit.PutInFront(Rig, 6)
			C:SetAttribute("Exposure", 1)
			Kit.Run(3)
			T.Eq(PS.Target(Rig), C, "a raised NPC fights the player it then sees")
		end)
	end,
	-- (Task 4 review) Raise doesn't take an NPC off a fight it is in
	RaiseKeepsAFight = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			PS.Alarm(Rig, Player) -- Alert on the player
			Raise(Rig, Kit.Spot() + Vector3.new(0, 0, 30))
			T.Eq(PS.Target(Rig), C, "still fights the player after a Raise elsewhere")
		end)
	end,

	-- ===== Task 5: bodies =====
	BodyFoundInView = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z), in the open at noon
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.Eq(PS.PhaseOf(Rig), "Alert", "it found the body: Alert")
			local Goal = PS.Goal(Rig)
			local Torso = TorsoOf(Body)
			T.True(Goal ~= nil and (Goal - Torso.Position).Magnitude <= 20, "searching around the body: " .. tostring(Goal))
			T.True(Info ~= nil and Info.Found == true, "the body is marked found")
			T.Eq(#Got, 1, "BodyFound fired once")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == Rig, "for that body, found by that Grunt")
		end) end) end)
	end,
	BodyNotBehind = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local _, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10))
			Kit.Face(Rig, Vector3.new(0, 0, 1)) -- its back to the body
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "its back to the body: still Unaware")
			T.True(Info ~= nil and not Info.Found, "not found")
			T.Eq(#Got, 0, "BodyFound didn't fire")
		end) end) end)
	end,
	BodyDarkIsSlower = function(T)
		-- the spot must be dark at night: no lamp (LightService's) and no light of any part within 60 studs
		local Spot, Lamps = Kit.Spot(), 0
		for Part in pairs(LS.Lamps) do
			if Part.Parent and (Part.Position - Spot).Magnitude <= 60 then Lamps += 1 end
		end
		for _, Part in ipairs(workspace:GetPartBoundsInRadius(Spot, 60)) do
			if Part:FindFirstChildWhichIsA("Light") then Lamps += 1 end
		end
		T.Eq(Lamps, 0, "no lamp within 60 studs of the spot")
		if Lamps > 0 then return end
		Kit.Guard(function() AtHour(12, function()
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10))
			Kit.PutPlayer(AWAY)
			local T1 = TimeToFind(Info, 4)
			T.True(T1 ~= nil, "noon: found within 4 s (" .. tostring(T1) .. ")")
			if not T1 then return end
			-- the same body and Grunt, the same distance, at midnight
			PS.RemoveBody(Body)
			PS.Reset(Rig)
			WorldClock.Hold(0)
			local Night = AddBody(Body, {Kind = "Dead", By = Player})
			T.Eq(TimeToFind(Night, 3 * T1), nil, ("midnight: not found within 3 x %.1f s"):format(T1))
			T.True((Night.Fill[Rig] or 0) > 0, "but it is seen, only more slowly: " .. tostring(Night.Fill[Rig]))
			T.Eq(PS.PhaseOf(Rig), "Unaware", "and the Grunt isn't searching")
		end) end)
	end,
	-- (pre-flight R7) a body under water is seen at x0.3, as a diver is (Perception.SubmergedMult)
	BodyUnderWaterIsSlower = function(T)
		Kit.Guard(function() AtHour(12, function()
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 12)) -- outside the water (it reaches 8 studs from the spot)
			Kit.PutPlayer(AWAY)
			Kit.Run(1)
			local Dry = Info.Fill[Rig] or 0
			T.True(Dry > 0 and not Info.Found, "dry: filling, not found yet in 1 s: " .. tostring(Dry))
			PS.RemoveBody(Body)
			PS.Reset(Rig)
			Water(true)
			local Ok, Err = pcall(function()
				local Swim = require(SSS.SwimService)
				T.True(Swim.HeadUnderwater(Body), "setup: the body is under the water")
				local Wet = AddBody(Body, {Kind = "Dead", By = Player})
				Kit.Run(1)
				T.Near((Wet.Fill[Rig] or 0) / math.max(Dry, 1e-6), 0.3, 0.05, "under water: x0.3 of the dry fill")
			end)
			Water(false)
			if not Ok then error(Err, 0) end
		end) end)
	end,
	FoundOnce = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			local First = Kit.Spawn("Grunt", At(0, 10))
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info ~= nil and Info.Found == true, "the first Grunt found it")
			local Second = Kit.Spawn("Grunt", At(10, 0)) -- 10 studs to the side
			Kit.Face(Second, Vector3.new(-1, 0, 0)) -- facing the body
			Kit.Run(4)
			T.Eq(#Got, 1, "BodyFound fired once in all")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == First, "by the first Grunt")
			T.Eq(PS.PhaseOf(Second), "Unaware", "the second isn't raised by a found body")
		end) end) end)
	end,
	TakedownBodyStays = function(T)
		Kit.Guard(function()
			local Kept = Kit.Spawn("Grunt", At(0, 0))
			local Plain = Kit.Spawn("Grunt", At(10, 0))
			Kept:SetAttribute("TakenDownBy", Player.Name)
			Kept.Humanoid.Health = 0
			Plain.Humanoid.Health = 0
			task.wait(6)
			T.True(Plain.Parent == nil, "control: a plain kill's body is gone by 6 s")
			T.True(Kept.Parent ~= nil, "a takedown's body is still there after 6 s")
		end)
	end,

	-- ===== Task 6 =====
	-- Knock(Victim, Seconds): the length wins over KnockedTime (TuningConfig.Downed.KnockedTime 20 when none is given)
	KnockLength = function(T)
		Kit.Guard(function()
			local Control = Kit.Spawn("Grunt", At(0, 0))
			DM.Knock(Control)
			T.Near((Control:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 20, 0.2, "control: no length, 20 s")
			local Rig = Kit.Spawn("Grunt", At(10, 0))
			DM.Knock(Rig, 7)
			T.Near((Rig:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 7, 0.2, "Knock(Rig, 7): 7 s")
		end)
	end,
	-- (pre-flight R6, spec §18.1) V picks up a takedown's dead body like a knocked one; it stays carried over 20 studs, is
	-- set down in front, and is still a body: a patrol finds it at the new spot
	CarryTakedownBody = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			Free(Body)
			Kit.PutPlayer(NEAR)
			local Root, H = C.HumanoidRootPart, C.Humanoid
			local WS = H.WalkSpeed
			local From = TorsoOf(Body).Position
			T.Eq(DM.Request(C, "Carry"), "Carry", "V picks up the takedown body")
			T.Eq(Body:GetAttribute("CarriedBy"), C.Name, "CarriedBy")
			for _ = 1, 10 do -- 20 studs in 1 s (-Z) while the carry loop runs
				Root.CFrame += Vector3.new(0, 0, -2)
				task.wait(0.1)
			end
			task.wait(0.2)
			T.Eq(C:GetAttribute("Carrying"), Body.Name, "still carried after 20 studs: a dead takedown body is held")
			local Rel = Root.CFrame:PointToObjectSpace(Body.HumanoidRootPart.Position)
			T.True((Rel - Vector3.new(-1.5, 0.1, 0)).Magnitude < 0.1, "over the left shoulder (CarryOffset): " .. tostring(Rel))
			T.Eq(DM.Request(C, "Carry"), "Dropped", "V again sets it down")
			T.Eq(Body:GetAttribute("CarriedBy"), nil, "CarriedBy cleared")
			T.Eq(C:GetAttribute("Carrying"), nil, "Carrying cleared")
			T.Eq(CarryWeld(), nil, "no weld left on the carrier")
			T.Near(H.WalkSpeed, WS, 1e-3, "the carrier walks as before")
			task.wait(0.5) -- (it settles on the floor)
			local Torso = TorsoOf(Body)
			T.True(Flat(Torso.Position - From) >= 18, ("it went with the carrier: %.1f studs"):format(Flat(Torso.Position - From)))
			-- a patrol 10 studs off the new spot, facing it
			local P = Vector3.new(Torso.Position.X, Kit.Spot().Y, Torso.Position.Z + 10)
			local Patrol = Kit.Spawn("Grunt", CFrame.lookAt(P, P + Vector3.new(0, 0, -1)))
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info.Found == true, "the patrol found the body at its new spot")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == Patrol, "BodyFound: that body, by that patrol")
			local Goal = PS.Goal(Patrol)
			T.True(Goal ~= nil and (Goal - Torso.Position).Magnitude <= 20, "searching around the new spot: " .. tostring(Goal))
		end) end) end)
	end,
	-- (pre-flight R6) B never takes a dead body, not even one handed to it; only V's lookup (Bodies) sees one
	GripRefusesCorpse = function(T)
		Kit.Guard(function()
			local Body = DeadBody(0, 0)
			Free(Body)
			Kit.PutPlayer(NEAR)
			local Where = C.HumanoidRootPart.Position
			local Gripped = false
			local Conn = Body:GetAttributeChangedSignal("GrippedBy"):Connect(function() Gripped = true end)
			local Ok, Err = pcall(function()
				T.Eq(DM.Grip(C), false, "B: nothing to grip")
				T.Eq(DM.Grip(C, Body), false, "B handed the body: refused")
			end)
			Conn:Disconnect()
			if not Ok then error(Err, 0) end
			T.Eq(Gripped, false, "the body was never gripped")
			T.True((C.HumanoidRootPart.Position - Where).Magnitude < 0.05, "the player wasn't moved onto it")
			T.Eq(C:GetAttribute("Gripping"), nil, "not gripping")
			T.Eq(DM.Nearest(C, 6), nil, "Grip's lookup skips the body")
			T.Eq(DM.Nearest(C, 6, {Bodies = true}), Body, "V's lookup (Bodies) finds it")
		end)
	end,
	-- (pre-flight R6) a carried body removed mid-carry (a knocked rig despawned, a corpse's 120 s) is dropped at once and
	-- cleanly: no weld left on the carrier, its walk back, and no other rig of the same name grabbed in its place
	DespawnMidCarry = function(T)
		Kit.Guard(function()
			local H = C.Humanoid
			local WS = H.WalkSpeed
			local Other = Kit.Spawn("Grunt", At(30, 30)) -- a live bandit of the same name, elsewhere
			local OtherAt = Other.HumanoidRootPart.Position
			local function Case(Target, What)
				T.Eq(Target.Name, Other.Name, "setup: " .. What .. " shares the other's name")
				Free(Target)
				Kit.PutPlayer(NEAR)
				T.True(DM.Carry(C, Target), What .. ": carried")
				Target:Destroy()
				task.wait(0.3)
				T.Eq(C:GetAttribute("Carrying"), nil, What .. ": dropped")
				T.Eq(CarryWeld(), nil, What .. ": no weld left on the carrier")
				T.Near(H.WalkSpeed, WS, 1e-3, What .. ": the carrier walks as before")
				T.True((Other.HumanoidRootPart.Position - OtherAt).Magnitude < 0.05, What .. ": the same-named bandit wasn't moved")
				T.Eq(Other:GetAttribute("CarriedBy"), nil, What .. ": nor marked carried")
				T.Eq(Other.Humanoid.PlatformStand, false, What .. ": nor detached")
			end
			local Knocked = Kit.Spawn("Grunt", At(0, 0))
			DM.Knock(Knocked)
			Case(Knocked, "a knocked bandit")
			Case((DeadBody(0, 0)), "a takedown body")
		end)
	end,
	-- (pre-flight R16 / D3) Lock, Attach (with its own offset, never the carry's) and Detach are DownedManager's, shared
	SharedWeldAndLock = function(T)
		Kit.Guard(function()
			T.True(type(DM.Lock) == "function" and type(DM.Attach) == "function" and type(DM.Detach) == "function",
				"DownedManager.Lock / Attach / Detach exist")
			local Holder = Kit.Spawn("Grunt", At(0, 0))
			local Target = Free(Kit.Spawn("Grunt", At(10, 0)))
			T.True(DM.Attach(Holder, Target, CFrame.new(0, 0, -2)), "attached")
			local Rel = Holder.HumanoidRootPart.CFrame:PointToObjectSpace(Target.HumanoidRootPart.Position)
			T.True((Rel - Vector3.new(0, 0, -2)).Magnitude < 0.05, "at the given offset: " .. tostring(Rel))
			T.Eq(Target.Humanoid.PlatformStand, true, "held")
			DM.Detach(Target)
			T.Eq(Holder.HumanoidRootPart:FindFirstChild("DownedWeld"), nil, "Detach removes the weld")
			T.Eq(Target.Humanoid.PlatformStand, false, "let go")
			local HH = Holder.Humanoid
			local WS = HH.WalkSpeed
			DM.Lock(Holder, true, 5)
			T.Eq(HH.WalkSpeed, 5, "locked to the given speed")
			T.Eq(HH.JumpHeight, 0, "no jump")
			DM.Lock(Holder, false)
			T.Near(HH.WalkSpeed, WS, 1e-3, "unlocked: its own speed back")
		end)
	end,
}

-- Play_Takedown (assassinations Task 4, 2026-10-27): takedowns inside the game VM (LMRunSuite). Every case runs in
-- TakedownKit.Guard on the kit's own floor high above the map, with rigs it spawned itself (never a world enemy, a
-- townsperson's real rig or the player), perception stepped by hand. Tasks 5-9 add their cases here.
-- Task 4: perception about takedowns -- a rig being taken down perceives nothing (Update, Hear, Perceived: pre-flight
-- R14); Glimpse, the one quick look every NPC takes at an attack; Raise, an Alert search at a spot with nobody to fight.
-- Task 5: bodies -- an enemy finds a registered body by sight (one ray, the tick's budget; light counts; under water
-- x0.3, pre-flight R7) and searches there, once per body; a takedown's corpse stays (Takedown.BodySeconds, not 4 s).
local SSS = game.ServerScriptService
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
}

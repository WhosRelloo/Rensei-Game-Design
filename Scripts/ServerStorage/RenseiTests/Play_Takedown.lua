-- Play_Takedown (assassinations Task 4, 2026-10-27): takedowns inside the game VM (LMRunSuite). Every case runs in
-- TakedownKit.Guard on the kit's own floor high above the map, with rigs it spawned itself (never a world enemy, a
-- townsperson's real rig or the player), perception stepped by hand. Tasks 5-9 add their cases here.
-- Task 4: perception about takedowns -- a rig being taken down perceives nothing (Update, Hear, Perceived: pre-flight
-- R14); Glimpse, the one quick look every NPC takes at an attack; Raise, an Alert search at a spot with nobody to fight.
local PS = require(game.ServerScriptService.PerceptionService)
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
}

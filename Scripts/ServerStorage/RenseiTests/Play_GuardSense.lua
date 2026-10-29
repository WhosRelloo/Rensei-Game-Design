-- Play_GuardSense (stealth missions Plan 1 Task 3, 2026-10-29): the hooks PerceptionService gives GuardService, inside the
-- game VM (LMRunSuite), on TakedownKit's floor with rigs the cases spawned themselves (Kit.Spawn: Unaware, passive, on the
-- Play-only floor; Kit.Run steps perception by hand). Every case looks the new API up inside itself and checks it exists
-- first, so before the change each case fails on its own message, not once at load. Every case that adds a listener or
-- replaces PickLookers puts it back in its own clean-up, even when the case fails.
--   * PhaseListenerFires: a PhaseChanged listener hears (Rig, New, Old) once, deferred.
--   * LostSightFiresOnce: LostSight fires once, at the spot the player was last seen, when an Alert NPC starts searching.
--   * HeardListenerAndDefaultPick (the control): Hear still returns every hearer, Heard lists them, and the default
--     PickLookers keeps today's rule (everyone goes to look); a sound nobody hears fires no Heard.
--   * PickLookersFilters / PickLookersErrorFallsBack: only the picked rigs investigate, Hear's return is still the count
--     of all hearers; a PickLookers that errors falls back to everyone.
--   * LookRefusals: Look sends an Unaware NPC to a spot, and refuses an Alert, knocked or taken-down NPC and an untracked part.
--   * FloorHoldsCautious: Floor keeps an NPC at Cautious or above, through a search and past CautiousTime.
--   * PerceptionTypeAttribute: the rig attribute PerceptionType (for the client's cone range).
local SSS = game.ServerScriptService
local PS = require(SSS.PerceptionService)
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Kit = require(script.Parent.TakedownKit)

-- a spot on the floor at the height of a rig's head, at (X, Z) from the kit's spot
local function Spot(X, Z) return Kit.At(X, Z).Position + Vector3.new(0, 3, 0) end

-- Body() with Fn in List; it comes out afterwards, whether Body failed or not
local function Listening(List, Fn, Body)
	table.insert(List, Fn)
	local Ok, Err = pcall(Body)
	local I = table.find(List, Fn)
	if I then table.remove(List, I) end
	if not Ok then error(Err, 0) end
end

-- Body() with PickLookers replaced by Fn; put back afterwards, whether Body failed or not
local function Picking(Fn, Body)
	local Old = PS.PickLookers
	PS.PickLookers = Fn
	local Ok, Err = pcall(Body)
	PS.PickLookers = Old
	if not Ok then error(Err, 0) end
end

return {
	-- Raise puts an Unaware NPC Alert: the listener hears (Rig, "Alert", "Unaware") once, and not inside Raise (deferred)
	PhaseListenerFires = function(T)
		T.True(type(PS.PhaseChanged) == "table", "PerceptionService.PhaseChanged exists")
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", Kit.At(0, 0))
			local Seen = {}
			Listening(PS.PhaseChanged, function(R, New, Old)
				if R == Rig then table.insert(Seen, {New, Old}) end
			end, function()
				PS.Raise(Rig, Spot(0, -10))
				T.Eq(#Seen, 0, "deferred: nothing ran inside Raise")
				task.wait()
				T.Eq(#Seen, 1, "heard once")
				T.Eq(Seen[1][1], "Alert", "the new phase")
				T.Eq(Seen[1][2], "Unaware", "the old phase")
			end)
		end)
	end,

	-- an Alert NPC loses the player it fought: LostSight fires once, with the spot they stood on, and not again
	LostSightFiresOnce = function(T)
		T.True(type(PS.LostSight) == "table", "PerceptionService.LostSight exists")
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", Kit.At(0, 0))
			-- full light, so the fill doesn't depend on the hour (Guard holds LightService still; Kit.Clean puts the saved Exposure back)
			Kit.Player().Character:SetAttribute("Exposure", 1)
			local Got = {}
			Listening(PS.LostSight, function(R, Where)
				if R == Rig then table.insert(Got, Where) end
			end, function()
				Kit.PutInFront(Rig, 10)
				Kit.Run(2.6)
				T.Eq(PS.PhaseOf(Rig), "Alert", "setup: Alert on the player")
				local Stood = Kit.Player().Character.HumanoidRootPart.Position
				Kit.PutPlayer(Kit.AWAY)
				Kit.Run(P.Memory + 0.6)
				task.wait()
				T.Eq(#Got, 1, "LostSight fired once")
				T.True(typeof(Got[1]) == "Vector3" and (Got[1] - Stood).Magnitude <= 3,
					"where: within 3 studs of the player's last spot, got " .. tostring(Got[1]))
				Kit.Run(1)
				task.wait()
				T.Eq(#Got, 1, "still once")
			end)
		end)
	end,

	-- the control: two Grunts 6 studs from a sound both hear it and both go to look (the default PickLookers is today's
	-- rule); the Heard listener gets both; a sound nobody hears fires no Heard
	HeardListenerAndDefaultPick = function(T)
		T.True(type(PS.Heard) == "table", "PerceptionService.Heard exists")
		T.True(type(PS.PickLookers) == "function", "PerceptionService.PickLookers exists")
		Kit.Guard(function()
			local A = Kit.Spawn("Grunt", Kit.At(6, 0))
			local B = Kit.Spawn("Grunt", Kit.At(-6, 0))
			local Heard = {}
			Listening(PS.Heard, function(Hearers, Position, Kind, Source)
				table.insert(Heard, {Hearers = Hearers, Position = Position, Kind = Kind, Source = Source})
			end, function()
				T.Eq(PS.Hear(Spot(0, 40), 12, "Land"), 0, "a sound out of reach: nobody hears it")
				T.Eq(#Heard, 0, "no Heard for a sound nobody heard")
				T.Eq(PS.Hear(Spot(0, 0), 12, "Land"), 2, "both hear it")
				T.Eq(#Heard, 1, "Heard fired once")
				T.Eq(#Heard[1].Hearers, 2, "two hearers listed")
				T.True(table.find(Heard[1].Hearers, A) ~= nil and table.find(Heard[1].Hearers, B) ~= nil, "both rigs are listed")
				T.Eq(Heard[1].Position, Spot(0, 0), "the position")
				T.Eq(Heard[1].Kind, "Land", "the kind")
				T.Eq(Heard[1].Source, nil, "no source")
				T.Eq(PS.PhaseOf(A), "Suspicious", "the first goes to look")
				T.Eq(PS.PhaseOf(B), "Suspicious", "the second goes to look")
			end)
		end)
	end,

	-- a PickLookers that keeps only the first hearer: Hear still counts both, only the picked one investigates
	PickLookersFilters = function(T)
		T.True(type(PS.PickLookers) == "function", "PerceptionService.PickLookers exists")
		Kit.Guard(function()
			local A = Kit.Spawn("Grunt", Kit.At(6, 0))
			local B = Kit.Spawn("Grunt", Kit.At(-6, 0))
			local Asked = {}
			local First
			Picking(function(Hearers, Position, Kind)
				table.insert(Asked, {N = #Hearers, Position = Position, Kind = Kind})
				First = Hearers[1]
				return {Hearers[1]}
			end, function()
				T.Eq(PS.Hear(Spot(0, 0), 12, "Land"), 2, "Hear still returns the count of all hearers")
			end)
			T.Eq(#Asked, 1, "PickLookers asked once")
			T.Eq(Asked[1].N, 2, "it was given both hearers")
			T.Eq(Asked[1].Position, Spot(0, 0), "it was given the position")
			T.Eq(Asked[1].Kind, "Land", "it was given the kind")
			local Other = (First == A) and B or A
			T.Eq(PS.PhaseOf(First), "Suspicious", "the picked rig investigates")
			T.Eq(PS.PhaseOf(Other), "Unaware", "the other keeps its routine")
		end)
	end,

	-- a PickLookers that errors (or returns nothing) falls back to everyone: the old rule
	PickLookersErrorFallsBack = function(T)
		T.True(type(PS.PickLookers) == "function", "PerceptionService.PickLookers exists")
		Kit.Guard(function()
			local A = Kit.Spawn("Grunt", Kit.At(6, 0))
			local B = Kit.Spawn("Grunt", Kit.At(-6, 0))
			Picking(function() error("a broken PickLookers") end, function()
				T.Eq(PS.Hear(Spot(0, 0), 12, "Land"), 2, "Hear still returns 2")
			end)
			T.Eq(PS.PhaseOf(A), "Suspicious", "the first still goes to look")
			T.Eq(PS.PhaseOf(B), "Suspicious", "the second still goes to look")
			PS.Reset(A); PS.Reset(B)
			Picking(function() return nil end, function()
				T.Eq(PS.Hear(Spot(0, 0), 12, "Land"), 2, "Hear still returns 2 (nothing picked back)")
			end)
			T.Eq(PS.PhaseOf(A), "Suspicious", "nil: the first still goes to look")
			T.Eq(PS.PhaseOf(B), "Suspicious", "nil: the second still goes to look")
		end)
	end,

	-- Look: an Unaware NPC goes to the spot (Suspicious, Goal = the spot); an Alert NPC with a focus, a knocked one, one being
	-- taken down and a part nothing tracks are refused
	LookRefusals = function(T)
		T.True(type(PS.Look) == "function", "PerceptionService.Look exists")
		Kit.Guard(function()
			local Where = Spot(0, -10)
			local Calm = Kit.Spawn("Grunt", Kit.At(-60, 0))
			T.Eq(PS.Look(Calm, Where), true, "an Unaware NPC looks")
			T.Eq(PS.PhaseOf(Calm), "Suspicious", "it is Suspicious")
			T.Eq(PS.Goal(Calm), Where, "its goal is the spot")
			local Fighting = Kit.Spawn("Grunt", Kit.At(-30, 0))
			PS.Alarm(Fighting, Kit.Player())
			T.Eq(PS.PhaseOf(Fighting), "Alert", "setup: Alert on the player")
			T.Eq(PS.Look(Fighting, Where), false, "an Alert NPC with a focus is refused")
			T.Eq(PS.PhaseOf(Fighting), "Alert", "it stays Alert")
			local Out = Kit.Spawn("Grunt", Kit.At(0, 0))
			Out:SetAttribute("Knocked", true)
			T.Eq(PS.Look(Out, Where), false, "a knocked NPC is refused")
			T.Eq(PS.PhaseOf(Out), "Unaware", "it stays Unaware")
			local Down = Kit.Spawn("Grunt", Kit.At(30, 0))
			Down:SetAttribute("TakenDownBy", Kit.Player().Name)
			T.Eq(PS.Look(Down, Where), false, "an NPC being taken down is refused")
			T.Eq(PS.PhaseOf(Down), "Unaware", "it stays Unaware")
			local Part = Instance.new("Part")
			Part.Anchored, Part.CanCollide, Part.Transparency = true, false, 1
			Part.Parent = workspace
			local Result = PS.Look(Part, Where)
			Part:Destroy()
			T.Eq(Result, false, "an untracked part is refused")
		end)
	end,

	-- Floor: never below Cautious until the time. It sets Cautious at once; the search ends, and it is still Cautious, past
	-- the normal 180 s only when the floor is later (Now() + 300 beats 180 s)
	FloorHoldsCautious = function(T)
		T.True(type(PS.Floor) == "function", "PerceptionService.Floor exists")
		T.True(type(PS.Now) == "function", "PerceptionService.Now exists")
		Kit.Guard(function()
			Kit.PutPlayer(Kit.AWAY)
			local Where = Spot(0, -10)
			local Rig = Kit.Spawn("Grunt", Kit.At(0, 0))
			PS.Floor(Rig, PS.Now() + 60)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "an Unaware NPC is Cautious at once")
			PS.Raise(Rig, Where)
			Kit.Run(P.SearchTime + 1)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "after the search: Cautious")
			Kit.Run(61)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "61 s later: still Cautious (the floor didn't shorten the 180 s)")
			local Rig2 = Kit.Spawn("Grunt", Kit.At(-60, 0))
			local F = PS.Now() + 300
			PS.Floor(Rig2, F)
			PS.Raise(Rig2, Spot(-60, -10))
			Kit.Run(P.SearchTime + 1)
			T.Eq(PS.PhaseOf(Rig2), "Cautious", "the second: Cautious after its search")
			T.True(PS.Npcs[Rig2].SearchUntil == nil, "its search has ended")
			T.True(PS.Npcs[Rig2].CautiousUntil >= F, "the floor won over the 180 s CautiousTime")
		end)
	end,

	-- the rig attribute the client reads for a cone's range
	PerceptionTypeAttribute = function(T)
		Kit.Guard(function()
			local Grunt = Kit.Spawn("Grunt", Kit.At(0, 0))
			T.Eq(Grunt:GetAttribute("PerceptionType"), "Grunt", "a Grunt")
			local Sentry = Kit.Spawn("StateSentry", Kit.At(30, 0))
			T.Eq(Sentry:GetAttribute("PerceptionType"), "Sentry", "a StateSentry")
		end)
	end,
}

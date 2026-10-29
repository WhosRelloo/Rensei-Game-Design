-- Play_Guard (stealth missions Plan 1 Task 4, 2026-10-29): GuardService's guards, nets and routine inside the game VM
-- (LMRunSuite), on TakedownKit's floor with rigs the cases spawned themselves (GuardKit.Guardsman: passive, freed so they
-- walk, tracked on a net of the case's own). The routine is real movement (the Mover, in real time); GuardKit.Guard holds
-- GuardService's and PerceptionService's clocks, so phases change only when a case steps them. Every case looks
-- GuardService up inside itself and checks the API it uses first, so before GuardService exists each case fails on its
-- own message, not once at load.
--   * TrackRefusesWithoutNet: Track refuses a rig with no Net (nil), and it isn't listed.
--   * PatrolWalksTheRoute: a 3-point straight route, 14 studs apart, not looping: point 2, point 3, then point 2 again
--     (back and forth) within 20 s, a pause of about 3 s standing still at point 3, and the walk at 8 (the patrol stroll).
--   * AlertInterruptsTheWalk / RoutineResumesAfterCalm: an Alarm mid-leg stops the Mover walk and puts back the def's
--     walk speed (14), and the Brain fights the player; once the guard calms (Lose) the routine walks on.
--   * PostGuardReturns: a post guard moved 8 studs off walks back (with the Mover) and faces its post's way.
--   * LookoutSweeps: a look-out sweeps its facing about its post's (more than 60 deg in all, never past +-50) on the spot.
--   * FailedLegsStop: every leg fails (each point sealed in a box): after 3 in a row (Guard.MaxWalkFails) it stands, with
--     no error and one warn at most.
--   * DeathUntracks: a death takes the guard out of Guards and off its net.
--   * SpawnWithNetIsTracked: EnemyService.Spawn of a RenseiEnemySpawn part with a Net tracks the rig there, its post at
--     the part; a mark that isn't a RenseiEnemySpawn part is no guard, Net or not.
--   * BanditUnchanged (the control): a plain Grunt walks home with Humanoid:MoveTo as today; the Mover never touches it.
-- Every expected number is written here by hand (never read from Rensei.Guard).
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local LogService = game:GetService("LogService")
local PS = require(SSS.PerceptionService)
local ES = require(SSS.EnemyService)
local Mover = require(SSS.TownsfolkService.Mover)
local Kit = require(script.Parent.TakedownKit)
local GK = require(script.Parent.GuardKit)

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
-- the flat heading of a look vector, degrees; and the signed difference of two headings, -180..180
local function Yaw(Look) return math.deg(math.atan2(-Look.X, -Look.Z)) end
local function Turn(A, B) return (A - B + 180) % 360 - 180 end
local function Off(LookA, LookB) return math.abs(Turn(Yaw(LookA), Yaw(LookB))) end

-- GuardService, after checking each named field exists; the case's name leads the message, so every case fails on its
-- own line while GuardService is missing
local function Need(T, Case, Names)
	local M = SSS:FindFirstChild("GuardService")
	local GS = M and require(M)
	for _, N in ipairs(Names) do
		T.True(GS ~= nil and GS[N] ~= nil, Case .. ": GuardService." .. N .. " exists")
	end
	return GS
end

-- (AlertInterruptsTheWalk, RoutineResumesAfterCalm) a guard on a 28-stud, 2-point route, caught mid-leg on the Mover,
-- then alarmed by the player (who waits AWAY: out of its sight, inside its leash); the Brain has had 0.5 s to answer
local function AlarmMidLeg(T, Case)
	Kit.PutPlayer(Kit.AWAY)
	local Route = GK.Route({Vector3.new(-14, 0, 0), Vector3.new(14, 0, 0)})
	local Rig, G = GK.Guardsman("StateGuard", Kit.At(-14, 0), {Net = GK.Net(Case), Route = Route})
	T.True(G ~= nil, "setup: tracked")
	local Root = Rig.HumanoidRootPart
	T.True(Kit.WaitFor(14, function()
		local H = Mover.Handle(Rig)
		local D = Flat(Root.Position - Route[1].Position).Magnitude
		return H ~= nil and H.Status == "walking" and D > 4 and D < 20
	end), "setup: mid-leg, walking with the Mover")
	PS.Alarm(Rig, Kit.Player())
	Kit.Run(0.4)
	task.wait(0.5)
	return Rig, G, Route
end

-- a box of Kit.Walls round a spot on the floor (4 sides and a roof): nothing walks in
local function SealedBox(Centre)
	for _, W in ipairs({
		{Vector3.new(0, 5, -3.5), Vector3.new(8, 10, 1)}, {Vector3.new(0, 5, 3.5), Vector3.new(8, 10, 1)},
		{Vector3.new(3.5, 5, 0), Vector3.new(1, 10, 8)}, {Vector3.new(-3.5, 5, 0), Vector3.new(1, 10, 8)},
		{Vector3.new(0, 10.5, 0), Vector3.new(8, 1, 8)},
	}) do
		Kit.Wall(CFrame.new(Centre + W[1]), W[2])
	end
end

return {
	TrackRefusesWithoutNet = function(T)
		local GS = Need(T, "TrackRefusesWithoutNet", {"Track"})
		GK.Guard(function()
			local Rig = Kit.Free(Kit.Spawn("StateGuard", Kit.At(0, 0)))
			T.Eq(GS.Track(Rig, {}), nil, "no Net: refused")
			T.Eq(GS.Track(Rig, {Net = ""}), nil, "an empty Net: refused")
			T.Eq(GS.Track(Rig, nil), nil, "no Info: refused")
			T.Eq(GS.Guards[Rig], nil, "not listed in Guards")
		end)
	end,

	-- spawned on point 1 (its first leg is there), the guard strolls to 2, to 3, and back to 2, pausing at each point
	PatrolWalksTheRoute = function(T)
		local GS = Need(T, "PatrolWalksTheRoute", {"Idle"})
		GK.Guard(function()
			local Route = GK.Route({Vector3.new(-14, 0, 0), Vector3.new(0, 0, 0), Vector3.new(14, 0, 0)})
			local Rig, G = GK.Guardsman("StateGuard", Kit.At(-14, 0), {Net = GK.Net("Patrol"), Route = Route, Loop = false})
			T.True(G ~= nil, "setup: tracked")
			T.True(GS.Guards[Rig] == G, "setup: listed in Guards")
			local Root, Hum = Rig.HumanoidRootPart, Rig.Humanoid
			local function Near(I) return Flat(Root.Position - Route[I].Position).Magnitude <= 2.5 end
			local Stage = 0 -- 1: been at point 2; 2: then at point 3; 3: then at point 2 again
			local Speeds, Odd = 0, {}
			local StillFrom, Still = nil, 0
			local T0 = os.clock()
			while os.clock() - T0 < 20 and Stage < 3 do
				local Now = os.clock()
				if Stage == 0 and Near(2) then Stage = 1
				elseif Stage == 1 and Near(3) then Stage = 2
				elseif Stage == 2 and Near(2) then Stage = 3 end
				local V = Flat(Root.AssemblyLinearVelocity).Magnitude
				if Stage == 2 and Near(3) and V < 1 then
					StillFrom = StillFrom or Now
					Still = math.max(Still, Now - StillFrom)
				else
					StillFrom = nil
				end
				local H = Mover.Handle(Rig)
				if H and H.Status == "walking" and V > 2 then
					Speeds += 1
					if Hum.WalkSpeed ~= 8 then table.insert(Odd, Hum.WalkSpeed) end
				end
				task.wait(0.05)
			end
			local Took = os.clock() - T0
			T.True(Stage >= 1, "it reached point 2")
			T.True(Stage >= 2, "then point 3")
			T.True(Stage >= 3, ("then point 2 again (back and forth), within 20 s (stage %d after %.1f s)"):format(Stage, Took))
			T.True(Still >= 2.5, ("it stood still at point 3 for at least 2.5 s (the 3 s pause), got %.2f s"):format(Still))
			T.True(Speeds > 0, "walk speed sampled while walking")
			T.True(#Odd == 0, "WalkSpeed 8 while walking, got " .. table.concat(Odd, ","))
		end)
	end,

	AlertInterruptsTheWalk = function(T)
		local GS = Need(T, "AlertInterruptsTheWalk", {"Interrupt"})
		GK.Guard(function()
			local Rig, G = AlarmMidLeg(T, "Alert")
			T.Eq(PS.PhaseOf(Rig), "Alert", "setup: Alert")
			T.Eq(Mover.Handle(Rig), nil, "the Mover walk stopped")
			T.Eq(G.Walk, nil, "no routine walk on the guard")
			T.Eq(Rig.Humanoid.WalkSpeed, 14, "the def's walk speed is back")
			T.Eq(Rig.HumanoidRootPart.Anchored, false, "its root is free")
			T.Eq(ES.Active[Rig].Target, Kit.Player().Character, "the Brain fights the player")
			T.True(GS.Guards[Rig] == G, "still a guard")
		end)
	end,

	RoutineResumesAfterCalm = function(T)
		local GS = Need(T, "RoutineResumesAfterCalm", {"Interrupt", "Idle"})
		GK.Guard(function()
			local Rig = AlarmMidLeg(T, "Calm")
			T.Eq(Mover.Handle(Rig), nil, "setup: the alarm stopped the walk")
			PS.Lose(Rig)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "setup: calmed (Cautious)")
			T.True(Kit.WaitFor(10, function()
				local H = Mover.Handle(Rig)
				return H ~= nil and H.Status == "walking"
			end), "within 10 s it walks its route again (the Mover handle is walking)")
			T.True(GS.Guards[Rig] ~= nil, "still a guard")
		end)
	end,

	PostGuardReturns = function(T)
		local GS = Need(T, "PostGuardReturns", {"Untrack"})
		GK.Guard(function()
			local Rig, G = GK.Guardsman("StateGuard", Kit.At(0, 0), {Net = GK.Net("Post")})
			T.True(G ~= nil and GS.Guards[Rig] == G, "setup: tracked")
			local Root = Rig.HumanoidRootPart
			task.wait(0.5)
			local Post = G.Post
			T.True(Flat(Root.Position - Post.Position).Magnitude <= 3, "setup: it stands at its post")
			Rig:PivotTo(Post * CFrame.new(8, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
			local Walked = false
			local Back = Kit.WaitFor(8, function()
				if Mover.Handle(Rig) then Walked = true end
				return Flat(Root.Position - Post.Position).Magnitude <= 3 and Off(Root.CFrame.LookVector, Post.LookVector) <= 20
			end)
			T.True(Back, ("within 8 s: within 3 studs of its post (%.1f) facing its way within 20 deg (%.0f)"):format(
				Flat(Root.Position - Post.Position).Magnitude, Off(Root.CFrame.LookVector, Post.LookVector)))
			T.True(Walked, "it walked back with the Mover")
			-- (the Mover's arrival turn holds the root anchored until the walk ends "arrived")
			T.True(Kit.WaitFor(2, function() return Mover.Handle(Rig) == nil end), "the walk ended")
			T.Eq(G.Walk, nil, "no routine walk left on the guard")
			T.Eq(Root.Anchored, false, "its root is free after the walk")
			T.True(Flat(Root.Position - Post.Position).Magnitude <= 3 and Off(Root.CFrame.LookVector, Post.LookVector) <= 20,
				"and it is still at its post, facing its way")
		end)
	end,

	LookoutSweeps = function(T)
		local GS = Need(T, "LookoutSweeps", {"Step"})
		GK.Guard(function()
			local Rig, G = GK.Guardsman("StateSentry", Kit.At(0, 0), {Net = GK.Net("Lookout"), Lookout = true})
			T.True(G ~= nil and GS.Guards[Rig] == G, "setup: tracked")
			local Root = Rig.HumanoidRootPart
			local PostLook = G.Post.LookVector
			local Prev = Yaw(Root.CFrame.LookVector)
			local Total, Most, Far = 0, 0, 0
			for _ = 1, 30 do -- 6 s
				GK.Step(0.2)
				local Y = Yaw(Root.CFrame.LookVector)
				Total += math.abs(Turn(Y, Prev))
				Prev = Y
				Most = math.max(Most, math.abs(Turn(Y, Yaw(PostLook))))
				Far = math.max(Far, Flat(Root.Position - G.Post.Position).Magnitude)
			end
			T.True(Total > 60, ("its facing moved more than 60 deg in all, got %.0f"):format(Total))
			T.True(Most <= 50, ("never more than 50 deg off its post's facing, got %.0f"):format(Most))
			T.True(Far <= 3, ("it stayed within 3 studs of its post, got %.2f"):format(Far))
		end)
	end,

	-- each route point sealed in a box (an arrival would reset the count: Fails counts failed legs IN A ROW), so every leg fails
	FailedLegsStop = function(T)
		local GS = Need(T, "FailedLegsStop", {"Reset"})
		GK.Guard(function()
			SealedBox(Kit.Spot() + Vector3.new(-20, 0, -20))
			SealedBox(Kit.Spot() + Vector3.new(20, 0, -20))
			local Route = GK.Route({Vector3.new(-20, 0, -20), Vector3.new(20, 0, -20)})
			local Warns, Errors = {}, {}
			local Conn = LogService.MessageOut:Connect(function(Msg, Type)
				local Ours = Msg:find("GuardService") or Msg:find("Mover") or Msg:find("EnemyService")
				if Ours and Type == Enum.MessageType.MessageWarning then table.insert(Warns, Msg) end
				if Ours and Type == Enum.MessageType.MessageError then table.insert(Errors, Msg) end
			end)
			local Ok, Err = pcall(function()
				local Rig, G = GK.Guardsman("StateGuard", Kit.At(0, 0), {Net = GK.Net("Fails"), Route = Route})
				T.True(G ~= nil, "setup: tracked")
				T.True(Kit.WaitFor(30, function() return G.Fails >= 3 end), "3 failed legs, got " .. tostring(G.Fails))
				local Root = Rig.HumanoidRootPart
				local Here = Root.Position
				local Walked = false
				Kit.WaitFor(3, function()
					if Mover.Handle(Rig) then Walked = true end
					return false
				end)
				T.Eq(G.Fails, 3, "it stopped at 3 (no fourth leg)")
				T.True(not Walked, "no walk after the third failed leg")
				T.True(Flat(Root.Position - Here).Magnitude < 1, "it stands where it is")
				T.Eq(GS.Idle(Rig), "standing", "Idle: standing")
			end)
			Conn:Disconnect()
			if not Ok then error(Err, 0) end
			T.True(#Errors == 0, "no error: " .. table.concat(Errors, " | "))
			T.True(#Warns <= 1, "one warn at most, got " .. #Warns .. ": " .. table.concat(Warns, " | "))
		end)
	end,

	DeathUntracks = function(T)
		local GS = Need(T, "DeathUntracks", {"Nets"})
		GK.Guard(function()
			local Net = GK.Net("Death")
			local Rig, G = GK.Guardsman("StateGuard", Kit.At(0, 0), {Net = Net})
			T.True(G ~= nil, "setup: tracked")
			local N = GS.Nets[Net]
			T.True(N ~= nil and N.Guards[Rig] == G, "setup: listed on its net")
			Rig.Humanoid.Health = 0
			task.wait(0.2)
			T.Eq(GS.Guards[Rig], nil, "out of Guards")
			T.Eq(N.Guards[Rig], nil, "off its net")
		end)
	end,

	SpawnWithNetIsTracked = function(T)
		local GS = Need(T, "SpawnWithNetIsTracked", {"RouteFor"})
		GK.Guard(function()
			local Net = GK.Net("Spawn")
			-- an unparented spawn part (never respawns; Kit.Clean's enemy sweep removes the rig)
			local function Mark(At, Tagged)
				local P = Instance.new("Part")
				P.Anchored, P.CanCollide, P.Transparency = true, false, 1
				P.CFrame = At
				P:SetAttribute("EnemyType", "StateGuard")
				P:SetAttribute("Net", Net)
				if Tagged then CollectionService:AddTag(P, "RenseiEnemySpawn") end
				return P
			end
			local Part = Mark(Kit.At(30, 0), true)
			local Rig = ES.Spawn(Part)
			T.True(typeof(Rig) == "Instance", "setup: spawned")
			Rig:SetAttribute("AIPassive", true)
			Rig:SetAttribute("Credited", true)
			local G = GS.Guards[Rig]
			T.True(G ~= nil, "the rig is a guard")
			T.Eq(G.Net, GS.Nets[Net], "on the spawn's net")
			T.Eq(G.Net.Name, Net, "the net's name")
			local Stand = Part.Position + Vector3.new(0, 3, 0)
			T.True(Flat(G.Post.Position - Stand).Magnitude < 0.5 and math.abs(G.Post.Position.Y - Stand.Y) < 2,
				"its post is at the part, got " .. tostring(G.Post.Position))
			T.True(Off(G.Post.LookVector, Part.CFrame.LookVector) < 5, "its post faces the part's way")
			T.Eq(G.Route, nil, "no Route attribute: a post guard")
			T.Eq(G.Lookout, false, "not a look-out")
			T.Eq(G.Speed, 14, "Speed: the def's WalkSpeed")
			local Plain = ES.Spawn(Mark(Kit.At(-30, 0), false))
			T.True(typeof(Plain) == "Instance", "setup: the untagged mark spawned")
			Plain:SetAttribute("AIPassive", true)
			Plain:SetAttribute("Credited", true)
			T.Eq(GS.Guards[Plain], nil, "a mark that isn't a RenseiEnemySpawn part makes no guard")
		end)
	end,

	-- the control: no Track, so the old walk home (Humanoid:MoveTo to its spawn mark) and never the Mover
	BanditUnchanged = function(T)
		local GS = Need(T, "BanditUnchanged", {"Guards"})
		GK.Guard(function()
			local Rig = Kit.Free(Kit.Spawn("Grunt", Kit.At(0, 0)))
			T.Eq(GS.Guards[Rig], nil, "a plain Grunt is no guard")
			local Root = Rig.HumanoidRootPart
			local Home = ES.Active[Rig].Home.Position
			task.wait(0.3)
			Rig:PivotTo(Rig:GetPivot() + Vector3.new(8, 0, 0))
			local MoverSeen, ToHome = false, false
			local Back = Kit.WaitFor(8, function()
				if Mover.Handle(Rig) then MoverSeen = true end
				if Flat(Rig.Humanoid.WalkToPoint - Home).Magnitude < 1 then ToHome = true end
				return Flat(Root.Position - Home).Magnitude <= 4.5
			end)
			T.True(Back, ("home within 8 s, %.1f studs off"):format(Flat(Root.Position - Home).Magnitude))
			T.True(ToHome, "it walked with Humanoid:MoveTo to its home")
			Kit.WaitFor(1, function()
				if Mover.Handle(Rig) then MoverSeen = true end
				return false
			end)
			T.True(not MoverSeen, "the Mover never walked it")
			T.Eq(GS.Guards[Rig], nil, "still no guard")
		end)
	end,
}

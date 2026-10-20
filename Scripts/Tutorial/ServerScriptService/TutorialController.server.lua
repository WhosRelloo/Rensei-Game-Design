-- TutorialController (Tutorial place only): runs the tutorial beats in Modules.Data.Rensei.TutorialSteps
-- for each player once their created character is in the world, and ends it with
-- ServerStorage.FinishTutorial (TutorialServer saves Flow.TutorialDone and teleports to Ye).
-- Character creation is never touched: this only reads the finished character from the save.
--
-- Progress is decided here, never by the client:
--   * hits (light / heavy / guard break / block / parry) from ProgressionService.HitListeners
--     (one training Dummy serves the whole tutorial: it takes hits, raises its guard for the Guard
--      beat, swings back in Defend, stands as a target for Alchemy, and fights to the knock in the Bout)
--   * dashes from StateRemote (the same request the dash itself sends)
--   * running, jumping, climbing and reaching places from the replicated character position
--   * alchemy casts from the AlchemyZ/XReadyAt attributes AlchemyService sets on a real cast
--   * the Dummy's Knocked attribute and death (the Bout)
-- The current beat is saved as Flow.TutorialStep so a rejoin resumes it. Dying restarts the beat.
-- Studio only: the attribute StudioStartStep (a beat Id) starts every player at that beat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Steps = require(Modules.Data.Rensei.TutorialSteps)
local Tuning = require(Modules.Data.Rensei.TuningConfig)
local Registry = require(Modules.Data.Rensei.Alchemy)
local ResourceManager = require(Modules.Managers.ResourceManager)
local BlockManager = require(Modules.Managers.BlockManager)
local AnimManager = require(Modules.Managers.AnimationManager)
local WCS = require(Modules.Framework.WCS)
local BlockingState = require(Modules.Skills.States.Blocking)
local StunState = require(Modules.Skills.States.Stun)
local ClimbingState = require(Modules.Skills.States.Climbing)
local SIDE_DISTANCE = 4 -- studs moved along the wall while climbing (the Wall beat's "Side" objective)
local FlowData = require(ServerScriptService.FlowData)
local ProgressionService = require(ServerScriptService.ProgressionService)
local AttackRunner = require(Modules.Managers.AttackRunner)
local SkillMods = require(Modules.Managers.SkillMods)
local AlchemyService = require(ServerScriptService.AlchemyService)
local UIService = require(ServerScriptService.UIService)

local Remote = ReplicatedStorage.Remotes:WaitForChild("TutorialRemote")
local Course = workspace.World.Map:WaitForChild("TutorialCourse")
local Live = workspace.World.Live
local Dummy = Live:WaitForChild("Dummy") -- the one training Dummy (replaced by a fresh copy if it's finished in the Bout)

local NEXT_DELAY = 1.6 -- seconds between finishing a beat and the next one starting
local RUN_SPEED = 25 -- horizontal speed that counts as running (walk is 20) -- PROPOSAL
local RUN_TIME = 1.5 -- seconds of running needed
local JUMP_CLEARANCE = 5.5 -- root this far above the ground = airborne (standing is ~3)
local REACH_VASK = 12
local FINALE_TIME = 9 -- the Gate opening + Truth's lines on the client before FinishTutorial
local GATE_MIN_TIME = 7 -- Vask finishes his last lines before the Gate can open
local GRIP_WINDOW = 5 -- a death this soon after the player took hold counts as the grip finish

-- The Dummy fighting back (Defend, Bout). PROPOSAL numbers.
local DUMMY_REACH = 7 -- it only swings at a player this close (it never walks)
local DUMMY_DAMAGE = 0.4 -- PhysicalMultiplier while it fights
local DUMMY_COMBO = {1, 3} -- lights per string
local DUMMY_PAUSE = {1.3, 2.2} -- seconds between strings
local BOUT_HEALTH = 300 -- its health in the Bout (it can't be beaten anywhere else)

local State = {} -- [Player] = {Step, Progress, Need, Token, Conns, CharConns, RunTime, Finished, GripAt, StartedAt}

local function Studio() return RunService:IsStudio() end

local function Root(Model)
	return Model and Model:FindFirstChild("HumanoidRootPart")
end

local function Disconnect(List)
	for _, C in ipairs(List) do C:Disconnect() end
	table.clear(List)
end

-- Inside a part's box (in its own space), with extra margin.
local function Inside(Part, Position, Margin)
	local P = Part.CFrame:PointToObjectSpace(Position)
	local H = Part.Size / 2 + Vector3.one * (Margin or 0)
	return math.abs(P.X) <= H.X and math.abs(P.Y) <= H.Y and math.abs(P.Z) <= H.Z
end

local GroundParams = RaycastParams.new()
GroundParams.FilterType = Enum.RaycastFilterType.Include
GroundParams.FilterDescendantsInstances = {workspace.World.Map}

local function Clearance(RootPart)
	local Hit = workspace:Raycast(RootPart.Position, Vector3.new(0, -50, 0), GroundParams)
	return Hit and (RootPart.Position.Y - Hit.Position.Y) or 50
end

-- ===== Alchemy beat: the player's own Z / X moves =====
local function AlchemyMoves(Player)
	local Affinity = AlchemyService.AffinityOf(Player)
	if not Affinity then return nil end
	local Moves = {}
	local Character = Player.Character
	for _, Slot in ipairs({"Z", "X"}) do
		-- Ye's rule (AlchemyService): Z comes with every path; X is bought in the Mastery tree. Only ask for
		-- X from a player who has it (SkillTreeService publishes the unlocks) -- Tutorial sync 2026-10-20
		local Usable = Slot == "Z" or (Character and SkillMods.Get(Character, "Unlock" .. Slot) >= 1)
		for _, Def in ipairs(Registry.ForAffinity(Affinity)) do
			-- only moves that are built (AlchemyService refuses the rest)
			if Usable and Def.Key == Slot and Tuning.Alchemy.Abilities[Def.Id] then
				Moves[Slot] = Def.Name
			end
		end
	end
	if not Moves.Z and not Moves.X then return nil end
	return Affinity, Moves
end

-- ===== Beats =====
local StartStep, Finale, ReadyDummyForBout -- forward

local function Send(Player, Kind, Payload)
	if Player.Parent then Remote:FireClient(Player, Kind, Payload) end
end

local function Complete(Player, S)
	local Index = S.Step
	if Steps.List[Index].Id == "Gate" then
		Finale(Player, S) -- the last beat opens the Gate instead of starting another
		return
	end
	S.Token += 1
	local Token = S.Token
	UIService.Notify(Player, "Banner", {Text = "Training - [" .. Steps.List[Index].Title .. "] Complete"})
	Send(Player, "StepDone", {Index = Index})
	task.delay(NEXT_DELAY, function()
		if State[Player] ~= S or S.Token ~= Token then return end
		StartStep(Player, Index + 1)
	end)
end

local function Progress(Player, Id, Amount)
	local S = State[Player]
	if not S or S.Done or S.Need[Id] == nil then return end
	local Have = S.Progress[Id]
	if Have >= S.Need[Id] then return end
	S.Progress[Id] = math.min(S.Need[Id], Have + (Amount or 1))
	Send(Player, "Progress", {Id = Id, Have = S.Progress[Id]})
	for Key, Need in pairs(S.Need) do
		if S.Progress[Key] < Need then return end
	end
	S.Done = true
	Complete(Player, S)
end

local function Current(Player, Id)
	local S = State[Player]
	return S and not S.Done and Steps.List[S.Step] and Steps.List[S.Step].Id == Id and S or nil
end


function Finale(Player, S)
	S.Finished = true
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid.WalkSpeed = 0 Humanoid.JumpHeight = 0 end
	Send(Player, "Finale", {Studio = Studio()})
	task.delay(FINALE_TIME, function()
		if State[Player] ~= S then return end
		local Profile = FlowData.Get(Player)
		if Profile then
			Profile.Data.Flow = Profile.Data.Flow or {}
			Profile.Data.Flow.TutorialStep = nil
		end
		local Finish = ServerStorage:WaitForChild("FinishTutorial", 10)
		if Finish then Finish:Fire(Player) end
		if Studio() then
			-- Studio can't teleport (TutorialServer says where it would go): let the player walk again
			Send(Player, "StudioDone", {})
			if Humanoid and Humanoid.Parent then
				Humanoid.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
				Humanoid.JumpHeight = game.StarterPlayer.CharacterJumpHeight
			end
		end
	end)
end

function StartStep(Player, Index)
	local S = State[Player]
	if not S then return end
	local Step = Steps.List[Index]
	if not Step then return end
	S.Step, S.Done, S.RunTime, S.GripAt = Index, false, 0, nil
	S.StartedAt = os.clock()
	S.Token += 1

	-- objectives (the alchemy beat builds its own from the player's path)
	local Objectives = {}
	local Vars = {}
	if Step.Id == "Alchemy" then
		local Affinity, Moves = AlchemyMoves(Player)
		if not Affinity then
			StartStep(Player, Index + 1) -- no path, or no moves built for it yet
			return
		end
		Vars.Affinity = Affinity
		Vars.ZName = Moves.Z or "nothing yet"
		Vars.XName = Moves.X or "nothing yet"
		for _, Slot in ipairs({"Z", "X"}) do
			if Moves[Slot] then
				table.insert(Objectives, {Id = Slot, Text = "Cast " .. Moves[Slot] .. " ({" .. Slot .. "})"})
			end
		end
	else
		for _, O in ipairs(Step.Objectives) do table.insert(Objectives, O) end
	end
	S.Progress, S.Need = {}, {}
	local Sent = {}
	for _, O in ipairs(Objectives) do
		S.Progress[O.Id] = 0
		S.Need[O.Id] = O.Count or 1
		table.insert(Sent, {Id = O.Id, Text = O.Text, Count = O.Count or 1, Have = 0})
	end

	local Profile = FlowData.Get(Player)
	if Profile then
		Profile.Data.Flow = Profile.Data.Flow or {}
		Profile.Data.Flow.TutorialStep = Step.Id
	end

	-- (the Dummy's behaviour follows the beat on its own; the Bout starts it fresh)
	local Character = Player.Character
	if Step.Id == "Bout" then ReadyDummyForBout() end
	if Step.Id == "Alchemy" and Character then
		ResourceManager.Set(Character, "Meter", ResourceManager.Max(Character, "Meter"))
	end

	Send(Player, "Step", {Index = Index, Count = #Steps.List, Id = Step.Id, Objectives = Sent, Vars = Vars})
end

-- ===== Per-character hooks =====
local function HookCharacter(Player, S, Character)
	Disconnect(S.CharConns)
	S.Finished = false
	-- the grip finish: DownedManager sets Gripping (the target's name) when the hold starts
	table.insert(S.CharConns, Character:GetAttributeChangedSignal("Gripping"):Connect(function()
		if Character:GetAttribute("Gripping") == Dummy.Name and Current(Player, "Bout") then
			S.GripAt = os.clock()
		end
	end))
	-- alchemy: AlchemyService sets AlchemyZReadyAt / AlchemyXReadyAt only once a cast is paid for
	table.insert(S.CharConns, Character.AttributeChanged:Connect(function(Name)
		local Slot = Name:match("^Alchemy(%u)ReadyAt$")
		if Slot and Current(Player, "Alchemy") and Character:GetAttribute(Name) then
			Progress(Player, Slot)
			-- keep the meter topped up for the second move
			task.delay(0.5, function()
				if Current(Player, "Alchemy") and Character.Parent then
					ResourceManager.Set(Character, "Meter", ResourceManager.Max(Character, "Meter"))
				end
			end)
		end
	end))
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if Humanoid then
		table.insert(S.CharConns, Humanoid.Died:Connect(function()
			S.Token += 1 -- cancel a pending "next beat"; the new character restarts this one
		end))
	end
end

local function Begin(Player)
	local Profile = FlowData.Wait(Player, 30)
	if not Profile or not Player.Parent then return end
	local Data = Profile.Data
	local Created = Data.Identity and Data.Identity.CharacterCreated
	if not Created and not Studio() then return end -- TutorialServer sends them to the menu
	if Data.Flow and Data.Flow.TutorialDone and not Studio() then
		-- already done (shouldn't arrive here): straight on to the game
		local Finish = ServerStorage:WaitForChild("FinishTutorial", 10)
		if Finish then Finish:Fire(Player) end
		return
	end

	local S = {Step = 1, Progress = {}, Need = {}, Token = 0, Done = false, RunTime = 0, CharConns = {}, Conns = {}}
	State[Player] = S

	local StartAt = Data.Flow and Steps.Index(Data.Flow.TutorialStep or "") or 1
	if Studio() and script:GetAttribute("StudioStartStep") then
		StartAt = Steps.Index(script:GetAttribute("StudioStartStep")) or StartAt
	end
	S.Step = StartAt

	local function OnCharacter(Character)
		-- CharacterHandler moves the character into World.Live, then sets it up
		local T0 = os.clock()
		while Character.Parent ~= Live and Character.Parent and os.clock() - T0 < 10 do task.wait(0.1) end
		if State[Player] ~= S or Player.Character ~= Character then return end
		HookCharacter(Player, S, Character)
		task.wait(1) -- let the HUD and the client script come up
		if State[Player] == S and Player.Character == Character then StartStep(Player, S.Step) end
	end
	table.insert(S.Conns, Player.CharacterAdded:Connect(OnCharacter))
	if Player.Character then task.spawn(OnCharacter, Player.Character) end
end

-- ===== The training Dummy =====
-- One Dummy for the whole tutorial. What it does follows the beat its player is on:
--   Strikes / Alchemy / others  stands open, can't be hurt
--   Guard                       holds its guard (the Blocking state, as Ye's Blocking dummy does),
--                               raising it again after each break
--   Defend                      swings back at a player in reach (can't be hurt)
--   Bout                        swings back, has BOUT_HEALTH and can be knocked; a grip finishes it,
--                               then a fresh Dummy stands up in its place
local Home = Dummy:GetPivot()
local Template = Dummy:Clone() -- for standing a fresh one up after the Bout
local LastHit = 0
local DummyConns = {}
local OnDummyKnocked, OnDummyDied -- forward
local Mode = "Open" -- the behaviour the Dummy is in (see WantedMode)

local function DummyWC()
	return Dummy.Parent and WCS.Character.GetCharacterFromInstance(Dummy)
end

local function DummyHumanoid()
	return Dummy:FindFirstChildOfClass("Humanoid")
end

local function HookDummy()
	Disconnect(DummyConns)
	table.insert(DummyConns, Dummy:GetAttributeChangedSignal("Knocked"):Connect(function()
		if Dummy:GetAttribute("Knocked") then OnDummyKnocked() end
	end))
	local H = DummyHumanoid()
	if H then table.insert(DummyConns, H.Died:Connect(function() OnDummyDied() end)) end
end
HookDummy()

-- Replaces a finished (or knocked-out) Dummy with a fresh copy at its spot.
local function RespawnDummy()
	local Old = Dummy
	local New = Template:Clone()
	New:PivotTo(Home)
	New.Parent = Live
	Dummy = New
	if Old and Old.Parent then Old:Destroy() end
	-- the same setup CharacterHandler gives the training dummies
	local WC = WCS.Character.new(New)
	BlockManager.Initiate(New)
	local H = DummyHumanoid()
	H.MaxHealth, H.Health = math.huge, math.huge
	H.Died:Once(function() pcall(function() WC:Destroy() end) end)
	HookDummy()
	Mode = "Open" -- the new Dummy picks up the current beat's behaviour on the next tick
end

function ReadyDummyForBout()
	local H = DummyHumanoid()
	if not H or H.Health <= 0 or Dummy:GetAttribute("Knocked") or not DummyWC() then
		RespawnDummy()
	else
		Mode = "Open" -- re-enter the Bout behaviour: full Bout health again on a restart
	end
end

local function PlayersOn(Id)
	local List = {}
	for Player in pairs(State) do
		if Current(Player, Id) then table.insert(List, Player) end
	end
	return List
end

function OnDummyKnocked()
	for _, Player in ipairs(PlayersOn("Bout")) do Progress(Player, "Knock") end
end

function OnDummyDied()
	local Finished = false
	for _, Player in ipairs(PlayersOn("Bout")) do
		local S = State[Player]
		if S.GripAt and os.clock() - S.GripAt <= GRIP_WINDOW then
			Progress(Player, "Knock")
			Progress(Player, "Grip")
			Finished = true
		else
			-- finished some other way (a burn ticking out, say): it stands up and they go again
			task.delay(3, function()
				if State[Player] == S and Current(Player, "Bout") then
					UIService.Notify(Player, "Toast", {Text = "????: \"Again. And this time, take hold of it.\""})
					StartStep(Player, S.Step)
				end
			end)
		end
	end
	if Finished then task.delay(3, RespawnDummy) end
end

-- The beat that decides the Dummy's behaviour (the Tutorial place runs one player per server).
local function WantedMode()
	for Player, S in pairs(State) do
		local Step = not S.Done and Steps.List[S.Step]
		if Step and (Step.Id == "Guard" or Step.Id == "Defend" or Step.Id == "Bout") then return Step.Id end
	end
	return "Open"
end

local Guard = nil -- the Blocking status this script started
local NextSwing = 0
local Swinging = false

local function SetMode(New)
	local H = DummyHumanoid()
	if Mode == "Guard" and Guard then
		pcall(function() Guard:Stop() end)
		Guard = nil
		AnimManager.StopAllAnims(Dummy)
		BlockManager.Negate(Dummy, -100)
	end
	if New == "Bout" then
		if H and H.Health > 0 then H.MaxHealth, H.Health = BOUT_HEALTH, BOUT_HEALTH end
		Dummy:SetAttribute("Knockable", true) -- knocked at 0 HP like a player; a grip finishes it
	elseif Mode == "Bout" then
		Dummy:SetAttribute("Knockable", nil)
		if H and H.Health > 0 then H.MaxHealth, H.Health = math.huge, math.huge end
	end
	local Fights = New == "Defend" or New == "Bout"
	Dummy:SetAttribute("PhysicalMultiplier", Fights and DUMMY_DAMAGE or nil)
	NextSwing = os.clock() + 1.5 -- a moment before the first swing
	Mode = New
end

-- The closest player on a fighting beat within reach.
local function FightTarget(DR)
	local Best, BestD = nil, DUMMY_REACH
	for _, Id in ipairs({"Defend", "Bout"}) do
		for _, Player in ipairs(PlayersOn(Id)) do
			local C = Player.Character
			local R = Root(C)
			local H = C and C:FindFirstChildOfClass("Humanoid")
			if R and H and H.Health > 0 and not C:GetAttribute("Knocked") then
				local D = (R.Position - DR.Position).Magnitude
				if D <= BestD then Best, BestD = C, D end
			end
		end
	end
	return Best
end

local function Face(DR, Target)
	local To = Target.HumanoidRootPart.Position - DR.Position
	To = Vector3.new(To.X, 0, To.Z)
	if To.Magnitude > 0.1 then DR.CFrame = CFrame.lookAt(DR.Position, DR.Position + To) end
end

-- One string of light strikes at Target, re-facing between hits (EnemyService's Grunt does the same).
local function Swing(WC, DR, Target)
	Swinging = true
	local Count = math.random(DUMMY_COMBO[1], DUMMY_COMBO[2])
	for I = 1, math.min(Count, #Tuning.Light.Hits) do
		local H = Target:FindFirstChildOfClass("Humanoid")
		if not Dummy.Parent or not H or H.Health <= 0 or Dummy:GetAttribute("Knocked") or WC:HasStatusEffects({StunState}) then break end
		if (Target.HumanoidRootPart.Position - DR.Position).Magnitude > DUMMY_REACH then break end
		Face(DR, Target)
		local Ok, Outcome = pcall(AttackRunner.Run, WC, Tuning.Light.Hits[I], "Light" .. I, {WalkSpeed = 0})
		if not Ok or Outcome == "Interrupted" or Outcome == "Whiff" then break end
	end
	NextSwing = os.clock() + DUMMY_PAUSE[1] + math.random() * (DUMMY_PAUSE[2] - DUMMY_PAUSE[1])
	Swinging = false
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local WC = DummyWC()
		local DR = Root(Dummy)
		if not WC or not DR then continue end
		local Wanted = WantedMode()
		if Wanted ~= Mode then SetMode(Wanted) end
		if Mode == "Guard" then
			if not WC:HasStatusEffects({BlockingState}) and not WC:HasStatusEffects({StunState}) then
				BlockManager.Negate(Dummy, -100) -- a fresh guard
				AnimManager.StopAllAnims(Dummy)
				AnimManager.Play(Dummy, "BlockIdle", {Looped = true})
				Guard = BlockingState.new(WC)
				Guard:Start()
			end
		elseif (Mode == "Defend" or Mode == "Bout") and not Swinging then
			local Target = FightTarget(DR)
			local Busy = Dummy:GetAttribute("Knocked") or Dummy:GetAttribute("GrippedBy")
				or AttackRunner.IsRunning(Dummy) or WC:HasStatusEffects({StunState})
			if Target and not Busy then
				Face(DR, Target)
				if os.clock() >= NextSwing then task.spawn(Swing, WC, DR, Target) end
			end
		end
	end
end)

-- Hits knock it around and it never walks back: put it home once it's been left alone for a moment.
task.spawn(function()
	while true do
		task.wait(0.5)
		local H = DummyHumanoid()
		if Dummy.Parent and H and H.Health > 0 and not Dummy:GetAttribute("Knocked") and not Swinging
			and os.clock() - LastHit > 1.5 and (Dummy:GetPivot().Position - Home.Position).Magnitude > 2 then
			Dummy:PivotTo(Home)
			for _, D in ipairs(Dummy:GetDescendants()) do
				if D:IsA("BasePart") then
					D.AssemblyLinearVelocity = Vector3.zero
					D.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
	end
end)

-- ===== Signals =====
-- Hits: every resolved hit in the game passes through here.
table.insert(ProgressionService.HitListeners, function(Attacker, Victim, Result)
	if Victim == Dummy then LastHit = os.clock() end
	local AttackerPlayer = Players:GetPlayerFromCharacter(Attacker)
	if AttackerPlayer then
		local Attack = Attacker:GetAttribute("CombatAttack") or ""
		if Victim == Dummy and Result == "Hit" and Current(AttackerPlayer, "Strikes") then
			if Attack:find("Heavy") then
				Progress(AttackerPlayer, "Heavy")
			elseif not Attack:find("Skill") and not Attack:find("Alchemy") then
				Progress(AttackerPlayer, "Light")
			end
		end
		if Victim == Dummy and Result == "GuardBroken" and Current(AttackerPlayer, "Guard") then
			Progress(AttackerPlayer, "Break")
		end
	end
	local VictimPlayer = Players:GetPlayerFromCharacter(Victim)
	if VictimPlayer and Current(VictimPlayer, "Defend") then
		if Result == "Blocked" then
			Progress(VictimPlayer, "Block")
		elseif Result == "Parried" or Result == "PerfectParried" then
			Progress(VictimPlayer, "Parry")
		end
	end
end)

-- Dashes: the dash's own i-frame request (keyboard and the touch button send the same one).
local LastDash = {}
ReplicatedStorage.Remotes.StateRemote.OnServerEvent:Connect(function(Player, States)
	if type(States) ~= "table" or not Current(Player, "Footwork") then return end
	for _, Info in ipairs(States) do
		if type(Info) == "table" and Info[1] == "IFrame" then
			local Now = os.clock()
			if not LastDash[Player] or Now - LastDash[Player] >= math.max(0.3, Tuning.Dash.Cooldown or 0) then
				LastDash[Player] = Now
				Progress(Player, "Dash")
			end
		end
	end
end)

-- Position checks, 10 times a second.
local function Check(Player, S, Now, Dt)
	local Character = Player.Character
	local R = Root(Character)
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local Step = Steps.List[S.Step]
	-- (StartedAt is set once the beat has really started on this character)
	if not R or not Humanoid or Humanoid.Health <= 0 or S.Done or not Step or not S.StartedAt then return end
	if Step.Id == "Footwork" then
		local V = R.AssemblyLinearVelocity
		if Vector3.new(V.X, 0, V.Z).Magnitude >= RUN_SPEED and not Character:GetAttribute("Dashing") then
			S.RunTime += Dt
			if S.RunTime >= RUN_TIME then Progress(Player, "Run") end
		end
		if Clearance(R) >= JUMP_CLEARANCE then Progress(Player, "Jump") end
	elseif Step.Id == "Report" then
		local Vask = Root(workspace.World.NPCs:FindFirstChild("Drillmaster Vask"))
		if Vask and (Vask.Position - R.Position).Magnitude <= REACH_VASK then Progress(Player, "Reach") end
	elseif Step.Id == "Wall" then
		-- climbing along the face (directional climb, 2026-10-18): horizontal travel while on the wall
		local WC = WCS.Character.GetCharacterFromInstance(Character)
		if WC and WC:HasStatusEffects({ClimbingState}) then
			S.ClimbFrom = S.ClimbFrom or R.Position
			local D = R.Position - S.ClimbFrom
			if Vector3.new(D.X, 0, D.Z).Magnitude >= SIDE_DISTANCE then Progress(Player, "Side") end
		else
			S.ClimbFrom = nil
		end
		if Inside(Course.WallTop, R.Position, 1) then Progress(Player, "Top") end
	elseif Step.Id == "Strikes" then
		if Character:GetAttribute("CombatMode") == true then Progress(Player, "Draw") end
	elseif Step.Id == "Gate" then
		if not S.Finished and Now - S.StartedAt >= GATE_MIN_TIME and Inside(Course.GateZone, R.Position, 0) then
			Progress(Player, "Gate")
		end
	end
end

task.spawn(function()
	local Last = os.clock()
	while true do
		task.wait(0.1)
		local Now = os.clock()
		local Dt = Now - Last
		Last = Now
		for Player, S in pairs(State) do
			-- one player's error must never stop everyone's checks
			local Ok, Err = pcall(Check, Player, S, Now, Dt)
			if not Ok then warn("[TutorialController] check failed for", Player.Name, Err) end
		end
	end
end)

Players.PlayerAdded:Connect(Begin)
for _, P in ipairs(Players:GetPlayers()) do task.spawn(Begin, P) end
Players.PlayerRemoving:Connect(function(Player)
	local S = State[Player]
	State[Player] = nil
	LastDash[Player] = nil
	if S then
		Disconnect(S.CharConns)
		Disconnect(S.Conns)
	end
end)

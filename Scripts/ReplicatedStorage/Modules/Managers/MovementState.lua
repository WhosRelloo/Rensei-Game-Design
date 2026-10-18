-- MovementState: the one traversal state of a character, owned by the server (2026-10-17).
--
--   Character attribute Traversal        = "Climb" | "WallRun" | "LedgeWalk" (later "Ledge" = hang, "Swim"),
--                                          nil = on foot / airborne
--   Character attribute TraversalSession = "<Seq>:<Kind>:<Reason>" -- the client's session number the state belongs
--       to; Kind "None" when it ended or was refused (Reason says why). One string, so it changes atomically.
--
-- Only the server writes these. JumpManager (client) asks through JumpRemote "ClimbState" ->
-- MovementState.Request, which refuses unless the character can traverse (alive; not knocked, gripped,
-- gripping, carried, carrying, stunned) and a wall is really in reach. While a state is active the server
-- re-checks every Traversal.CheckEvery seconds and ends it on stun / knock / grip / carry / death, when the
-- wall (for a ledge walk: the authored ledge strip, TuningConfig.LedgeWalk.Tag) is gone (Traversal.MissesToEnd checks in a row) or past the wall-run time cap. JumpManager lets go
-- whenever the server ends or refuses its CURRENT session (the Seq stops a late "ended" for an old session
-- from dropping a new one). The Climbing status (no attacking on a wall) is started / stopped here.
-- Numbers: TuningConfig.Traversal (PROPOSAL).
-- SWIM (2026-10-18, owner decision 6): set ONLY by the server (SwimService -> MovementState.SetSwim), never
-- requested by a client. It carries the Climbing status like the other kinds (no attacking / alchemy), survives a
-- stun (you're still in the water) and ends on knock / grip / carry / death or when SwimService sees dry land.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local MovementState = {}

-- kinds a client may request today (Ledge hang / Swim join with their phases)
MovementState.Kinds = {Climb = true, WallRun = true, LedgeWalk = true}
-- character attributes that forbid traversal (DownedManager)
MovementState.Blocking = {"Knocked", "GrippedBy", "Gripping", "Carrying", "CarriedBy"}

function MovementState.Get(Character)
	return Character and Character:GetAttribute("Traversal") or nil
end

-- the first blocking attribute set on the character, or nil
function MovementState.Blocked(Character)
	for _, Name in ipairs(MovementState.Blocking) do
		if Character:GetAttribute(Name) then return Name end
	end
	return nil
end

-- "<Seq>:<Kind>:<Reason>" -> Seq (number), Kind, Reason
function MovementState.ParseSession(Session)
	if type(Session) ~= "string" then return nil end
	local Seq, Kind, Reason = string.match(Session, "^(%-?%d+):(%a+):?(.*)$")
	return tonumber(Seq), Kind, Reason
end

if RunService:IsServer() then
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local SkillMods = require(ReplicatedStorage.Modules.Managers.SkillMods)
	local Climbing = require(ReplicatedStorage.Modules.Skills.States.Climbing)
	local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)

	-- plain tables with explicit cleanup (never weak-keyed; see ARCHITECTURE gotchas)
	local Sessions = {} -- [Character] = {Kind, Seq, Started, Token, Misses}
	local Tracked = {} -- [Character] = {connections}

	local WallParams = RaycastParams.new()
	WallParams.FilterType = Enum.RaycastFilterType.Include

	local Directions = {}
	for I = 0, 7 do
		local A = I * math.pi / 4
		table.insert(Directions, Vector3.new(math.cos(A), 0, math.sin(A)))
	end

	-- a wall (not floor or ceiling) of the map within reach, around the root at body and head height
	local function WallInReach(Character)
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root then return false end
		WallParams.FilterDescendantsInstances = {workspace.World.Map}
		local Reach = Tuning.Traversal.ValidateReach
		for _, Height in ipairs({0, 3}) do
			local Origin = Root.Position + Vector3.new(0, Height, 0)
			for _, D in ipairs(Directions) do
				local Hit = workspace:Raycast(Origin, D * Reach, WallParams)
				if Hit and math.abs(Hit.Normal.Y) < 0.7 then return true end
			end
		end
		return false
	end

	-- on an authored ledge (a part tagged TuningConfig.LedgeWalk.Tag): the root over its strip, inside its
	-- endpoints (plus a small tolerance for lag), and not far above it. The ledge walk is only valid there.
	local CollectionService = game:GetService("CollectionService")
	local function LedgeNear(Character)
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root then return false end
		local Tol = Tuning.LedgeWalk.ServerTolerance
		for _, Part in ipairs(CollectionService:GetTagged(Tuning.LedgeWalk.Tag)) do
			if Part:IsA("BasePart") then
				local P = Part.CFrame:PointToObjectSpace(Root.Position)
				local S = Part.Size
				if math.abs(P.X) <= S.X / 2 + Tol and math.abs(P.Z) <= S.Z / 2 + Tol + 1
					and P.Y >= S.Y / 2 - 1 and P.Y <= S.Y / 2 + 6 then
					return true
				end
			end
		end
		return false
	end

	-- standing on map ground
	local function GroundBelow(Character)
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root then return false end
		WallParams.FilterDescendantsInstances = {workspace.World.Map}
		return workspace:Raycast(Root.Position, Vector3.new(0, -6, 0), WallParams) ~= nil
	end

	local function CharacterState(Character)
		return WCS.Character.GetCharacterFromInstance(Character)
	end

	local function Alive(Character)
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		return Humanoid ~= nil and Humanoid.Health > 0
	end

	local function SetClimbing(Character, On)
		local CS = CharacterState(Character)
		if not CS then return end
		if On then
			if not CS:HasStatusEffects({Climbing}) then Climbing.new(CS):Start() end
		else
			for _, Status in pairs(CS:GetAllActiveStatusEffectsOfType(Climbing)) do Status:Stop() end
		end
	end

	local function Publish(Character, Seq, Kind, Reason)
		Character:SetAttribute("Traversal", Kind ~= "None" and Kind or nil)
		Character:SetAttribute("TraversalSession", string.format("%d:%s:%s", Seq or 0, Kind, Reason or ""))
	end

	-- why this character can't traverse right now, or nil
	local function Refusal(Character)
		if not Alive(Character) then return "Dead" end
		local Blocked = MovementState.Blocked(Character)
		if Blocked then return Blocked end
		local CS = CharacterState(Character)
		if not CS then return "NoCharacter" end
		if CS:HasStatusEffects({Stun}) then return "Stun" end
		return nil
	end

	-- End the current state (if any). Reason is published for debugging / the client.
	function MovementState.Clear(Character, Reason)
		local S = Sessions[Character]
		if not S then return end
		Sessions[Character] = nil
		SetClimbing(Character, false)
		if Character.Parent then Publish(Character, S.Seq, "None", Reason) end
	end

	-- Seconds a kind may last before the server ends it (nil = no cap; a climb is bounded by stamina).
	local function Cap(Character, Kind)
		if Kind == "WallRun" then
			return Tuning.Parkour.WallRunDuration * SkillMods.Mult(Character, "WallRunTime") + Tuning.Traversal.WallRunGrace
		end
		return nil
	end

	local function Watch(Character, S)
		local Token = S.Token
		task.spawn(function()
			while true do
				task.wait(Tuning.Traversal.CheckEvery)
				if Sessions[Character] ~= S or S.Token ~= Token then return end
				local Why = Refusal(Character)
				if Why then MovementState.Clear(Character, Why) return end
				local Limit = Cap(Character, S.Kind)
				if Limit and os.clock() - S.Started > Limit then MovementState.Clear(Character, "TimeCap") return end
				if (S.Kind == "LedgeWalk" and LedgeNear(Character)) or (S.Kind ~= "LedgeWalk" and WallInReach(Character)) then
					S.Misses = 0
				else
					S.Misses += 1
					if S.Misses >= Tuning.Traversal.MissesToEnd then MovementState.Clear(Character, S.Kind == "LedgeWalk" and "OffLedge" or "NoWall") return end
				end
			end
		end)
	end

	-- Server only (SwimService): enter / leave the Swim state. Entering never replaces a climb, wall run or ledge
	-- walk the player is in (climbing out of the water onto a wall keeps the climb); returns whether it is now Swim.
	-- Enemies use it too (owner 2026-10-18): an untracked NPC is tracked on its first swim, for the same cleanup.
	function MovementState.SetSwim(Character, On)
		local Current = Sessions[Character]
		if not On then
			if Current and Current.Kind == "Swim" then MovementState.Clear(Character, "Shore") end
			return false
		end
		if Current then return Current.Kind == "Swim" end
		if not Alive(Character) or MovementState.Blocked(Character) then return false end
		if not Tracked[Character] then MovementState.Track(Character, CharacterState(Character)) end
		local S = {Kind = "Swim", Seq = 0, Started = os.clock(), Token = {}, Misses = 0}
		Sessions[Character] = S
		SetClimbing(Character, true)
		Publish(Character, 0, "Swim")
		return true
	end

	-- JumpRemote "ClimbState" (via JumpManager.ClimbState): On = start / stop, Kind, Seq = client session number.
	function MovementState.Request(Player, On, Kind, Seq)
		local Character = Player.Character
		if not Character or not Tracked[Character] then return end
		if type(Seq) ~= "number" or Seq ~= Seq or Seq % 1 ~= 0 or math.abs(Seq) > 2^31 then Seq = 0 end
		local Current = Sessions[Character]

		if not On then
			-- a client never ends the server's swim state
			if Current and Current.Kind == "Swim" then return end
			-- ignore a late stop for an older session than the one running
			if Current and Seq ~= 0 and Current.Seq ~= 0 and Seq < Current.Seq then return end
			MovementState.Clear(Character, "Client")
			return
		end

		if type(Kind) ~= "string" or not MovementState.Kinds[Kind] then return end
		-- no climbing / wall running from the water: the server's swim state stays until dry land
		if Current and Current.Kind == "Swim" then return end
		local Why = Refusal(Character)
			or (Kind == "LedgeWalk" and not LedgeNear(Character) and "NoLedge")
			or (Kind ~= "LedgeWalk" and not WallInReach(Character) and "NoWall") or nil
		if Why then
			if Current then
				Sessions[Character] = nil
				SetClimbing(Character, false)
			end
			Publish(Character, Seq, "None", "Refused:" .. Why)
			return
		end
		-- climb <-> wall run hand straight over; a new session replaces the old one
		local S = {Kind = Kind, Seq = Seq, Started = os.clock(), Token = {}, Misses = 0}
		Sessions[Character] = S
		SetClimbing(Character, true)
		Publish(Character, Seq, Kind)
		Watch(Character, S)
	end

	-- Every player character (CharacterHandler): end traversal the moment the character is stunned,
	-- knocked, gripped, carried or dies, and drop all state when it is removed.
	function MovementState.Track(Character, CS)
		if Tracked[Character] then return end
		local Conns = {}
		Tracked[Character] = Conns
		for _, Name in ipairs(MovementState.Blocking) do
			table.insert(Conns, Character:GetAttributeChangedSignal(Name):Connect(function()
				if Character:GetAttribute(Name) then MovementState.Clear(Character, Name) end
			end))
		end
		local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10)
		if Humanoid then
			table.insert(Conns, Humanoid.Died:Connect(function() MovementState.Clear(Character, "Dead") end))
		end
		if CS then
			table.insert(Conns, CS.StatusEffectAdded:Connect(function(Status)
				local function Check()
					local S = Sessions[Character]
					if S and S.Kind ~= "Swim" and CS:HasStatusEffects({Stun}) then MovementState.Clear(Character, "Stun") end
				end
				if Status.Started then Status.Started:Connect(Check) end
				task.defer(Check)
			end))
		end
		table.insert(Conns, Character.AncestryChanged:Connect(function(_, Parent)
			if Parent then return end
			Sessions[Character] = nil
			for _, C in ipairs(Conns) do C:Disconnect() end
			Tracked[Character] = nil
		end))
	end
end

return MovementState

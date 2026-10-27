-- TakedownKit (assassinations Task 4, 2026-10-27): the takedown suites' shared fixture (Play_Takedown, which Tasks 5-9
-- extend). Required, never copied. Run in the game VM (LMRunSuite), never in Edit. It builds on SmokeKit (pre-flight
-- Rulings R5 and D5): SmokeKit's TempPart (the floor and walls), Guarded (the clean-up and the character put back) and
-- the perception helpers moved there from Play_Stealth (Run, SpawnEnemy, RemoveEnemy, SweepEnemies). Nothing here
-- re-implements them.
--   * Kit.Player(): the test player (the first in the server), whose character every helper moves and restores.
--   * Kit.Spot(): the test spot, the top centre of a Play-only floor high above the map (Ruling R4: Task 1's survey spots
--     are in town, where Glimpse, Call and fleeing townsfolk would reach real NPCs). X/Z are Task 1's survey spot for
--     this place (survey_ye.json / survey_foundry.json, 2026-10-27); Y is SPOT_Y. Guard lays the floor there; outside
--     Guard there is none.
--   * Kit.Spawn(Type, At, Opts) -> Rig: EnemyService.Spawn from an unparented mark (EnemyType = Type), so it never
--     respawns; AIPassive, and Credited unless Opts.Credit (a takedown test of credit); its root anchored and the rig
--     standing at At (a CFrame on the floor: where it stands and which way it faces); then, once PerceptionService
--     tracks it (or after 2 s for a type it never tracks), reset to Unaware. Only inside Guard.
--   * Kit.Face(Rig, Dir): the rig turned, where it stands, to face Dir (level).
--   * Kit.PutPlayer(At): the player's character root anchored at At (a CFrame), velocity zeroed, 0.15 s to settle.
--   * Kit.PutInFront(Rig, Dist) / Kit.PutBehind(Rig, Dist, AngleFromBack): the player Dist studs from the rig's root,
--     straight ahead of it / behind it turned AngleFromBack degrees (default 0) off its back, facing it.
--   * Kit.Wall(At, Size): an anchored test part (SmokeKit.TempPart), removed when Guard ends.
--   * Kit.Run(Seconds): SmokeKit.Run (PerceptionService.Step(0.2) repeated; Guard holds SetAuto(false)).
--   * Kit.Guard(Body): saves the character's CombatMode, Crouching and Exposure (SmokeKit.Guarded saves its pivot and
--     Anchored); PerceptionService and LightService SetAuto(false); lays the floor; runs Body in a pcall; then Kit.Clean
--     and the put-back. Re-raises Body's error.
--   * Kit.Clean(): Guard's clean-up (Guard calls it; SmokeKit.Guarded then removes the parts and puts the character
--     back): a carry the case left dropped and any carry weld off the player's root (Task 6), every rig the kit made removed (and any other enemy left on the floor), every townsperson Folk made despawned with its post (Task 9), TakingDown, TakedownReadyAt and
--     LastTakedownResult cleared on the character, the saved attributes restored, both loops SetAuto(true). (Task 7) A
--     crouch Kit.Crouch started is stopped; a takedown left running is waited out (its victim is gone, so it ends as an
--     interrupt), and TakedownService forgets the player's cooldown (Forget), so no case starts on the last one's.
--   * Kit.Crouch(On) (Task 7): the player crouches as CharacterHandler's crouch does (a WCS Stun stored in
--     AttackRunner.CrouchStuns, Crouching = true), or stands up again (only a crouch the kit started is stopped).
--   * (Task 8 fix round) the cases' shared helpers, moved here unchanged from Play_Takedown for Play_TakedownHard: At,
--     AWAY, NEAR, AtHour, AddBody, DeadBody, CarryWeld, Free, WaitFor, Service, Result, Calm, Assassinate, KnockOut,
--     Finished, Behind, Deed, LAW and GrippedBodyHeat (each described where it is defined, below).
--   * Kit.Folk(Name, At) -> Id, Rig (Task 9, pre-flight R10): a test townsperson of the case's own on the floor, standing
--     at At (a CFrame: where and which way it faces) at a post of its own (SmokeKit.FolkPost / FolkDef / SpawnFolk,
--     the fixture Play_TownsfolkHurt uses), once PerceptionService tracks it as a watcher (2 s at most). Only inside
--     Guard; Kit.Clean despawns it and removes its post.
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local PS = require(SSS.PerceptionService)
local LS = require(SSS.LightService)
local SmokeKit = require(script.Parent.SmokeKit)
local DownedManager = require(game:GetService("ReplicatedStorage").Modules.Managers.DownedManager)
local Modules = game:GetService("ReplicatedStorage").Modules
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local CrouchStuns = require(Modules.Managers.AttackRunner).CrouchStuns

local Kit = {}

-- Task 1's survey spot X/Z by place (Art/Studio/Takedown/survey_*.json, 2026-10-27): Ye from Lindenmoor square's spawn,
-- Foundry from the Foundry spawn
local SURVEY = {
	[106992859583940] = Vector3.new(-32, 0, -700), -- Ye: (-32, 9, -700) on Lindenmoor's grass
	[109591196441030] = Vector3.new(-680, 0, 392), -- Foundry: (-680, 4, 392) on Foundry ground
}
local SPOT_Y = 3000 -- PROPOSAL (Ruling R4): above both maps (their tops are under y 430); GunKit's floor is at 2000, Play_Stealth's at 2500
local FLOOR = Vector3.new(160, 1, 160) -- PROPOSAL: room for rigs 60 studs apart (RaiseSearches) and the player
local SWEEP = 120 -- PROPOSAL: studs from the spot; Clean removes any enemy this near (a Spawn that threw half-way)
local SAVED = {"CombatMode", "Crouching", "Exposure"} -- the character attributes Guard puts back
local CLEARED = {"TakingDown", "TakedownReadyAt", "LastTakedownResult"} -- cleared after every case

local Made = {} -- the rigs Spawn made, until Clean
local FolkMade = {} -- (Task 9) the townsfolk Folk made, {Id, Post}, until Clean
local Saved = nil -- the attributes Guard saved, while a Guard runs

function Kit.Player() return Players:GetPlayers()[1] end

function Kit.Spot()
	local XZ = SURVEY[game.PlaceId]
	assert(XZ, "TakedownKit: no survey spot for place " .. tostring(game.PlaceId))
	return Vector3.new(XZ.X, SPOT_Y, XZ.Z)
end

function Kit.Spawn(Type, At, Opts)
	Opts = Opts or {}
	assert(Saved ~= nil, "TakedownKit.Spawn runs inside Guard (its floor and its clean-up)")
	local Rig = SmokeKit.SpawnEnemy(Type, At.Position)
	table.insert(Made, Rig)
	Rig:SetAttribute("AIPassive", true)
	if not Opts.Credit then Rig:SetAttribute("Credited", true) end
	Rig.HumanoidRootPart.Anchored = true
	Rig:PivotTo(At + Vector3.new(0, 3, 0)) -- the root 3 studs above the floor, as Play_Stealth's Grunt stands
	local T0 = os.clock()
	while not PS.Tracks(Rig) and os.clock() - T0 < 2 do task.wait(0.05) end
	PS.Reset(Rig)
	return Rig
end

function Kit.Folk(Name, At)
	assert(Saved ~= nil, "TakedownKit.Folk runs inside Guard (its floor and its clean-up)")
	local Id = "TDF_" .. Name .. "_" .. tostring(math.random(1e6))
	table.insert(FolkMade, {Id = Id, Post = SmokeKit.FolkPost(Id, At, "Work")})
	local Rig = SmokeKit.SpawnFolk(SmokeKit.FolkDef(Id, "Takedown Test " .. Name, {{0, 24, Id}}, 3000 + #FolkMade))
	local T0 = os.clock()
	while not PS.Tracks(Rig) and os.clock() - T0 < 2 do task.wait(0.05) end
	return Id, Rig
end

function Kit.Face(Rig, Dir)
	local Pos = Rig:GetPivot().Position
	Rig:PivotTo(CFrame.lookAt(Pos, Pos + Vector3.new(Dir.X, 0, Dir.Z)))
end

function Kit.PutPlayer(At)
	local C = Kit.Player().Character
	local Root = C.HumanoidRootPart
	Root.Anchored = true
	C:PivotTo(At)
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end

-- the player Dist studs from the rig's root along Dir (level), facing the rig
local function Around(Rig, Dir, Dist)
	local At = Rig.HumanoidRootPart.Position
	local Pos = At + Vector3.new(Dir.X, 0, Dir.Z).Unit * Dist
	Kit.PutPlayer(CFrame.lookAt(Pos, Vector3.new(At.X, Pos.Y, At.Z)))
end

function Kit.PutInFront(Rig, Dist)
	Around(Rig, Rig.HumanoidRootPart.CFrame.LookVector, Dist)
end

function Kit.PutBehind(Rig, Dist, AngleFromBack)
	local Back = -Rig.HumanoidRootPart.CFrame.LookVector
	Around(Rig, CFrame.Angles(0, math.rad(AngleFromBack or 0), 0):VectorToWorldSpace(Back), Dist)
end

function Kit.Wall(At, Size)
	return SmokeKit.TempPart({Name = "Takedown_Wall", Size = Size, CFrame = At})
end

Kit.Run = SmokeKit.Run

local KitCrouch = nil -- the crouch Stun Kit.Crouch started, until it stops it
function Kit.Crouch(On)
	local C = Kit.Player().Character
	local WC = WCS.Character.GetCharacterFromInstance(C)
	assert(WC, "the player has a WCS character")
	if On then
		if not CrouchStuns[WC] then
			local S = Stun.new(WC)
			S:Start()
			CrouchStuns[WC] = S
			KitCrouch = S
		end
		C:SetAttribute("Crouching", true)
	elseif KitCrouch then
		if CrouchStuns[WC] == KitCrouch then CrouchStuns[WC] = nil end
		pcall(function() KitCrouch:Stop() end)
		KitCrouch = nil
		C:SetAttribute("Crouching", nil)
	end
end

function Kit.Clean()
	Kit.Crouch(false)
	-- (Task 6) a case that failed mid-carry: set the body down first (the carrier's walk back), and no carry weld stays
	-- on the player's root
	local Char = Kit.Player().Character
	if Char:GetAttribute("Carrying") then pcall(DownedManager.Drop, Char) end
	for _, W in ipairs(Char.HumanoidRootPart:GetChildren()) do
		if W.Name == "DownedWeld" then W:Destroy() end
	end
	for _, Rig in ipairs(Made) do SmokeKit.RemoveEnemy(Rig) end
	table.clear(Made)
	-- (Task 9) the case's townsfolk and their posts
	for _, X in ipairs(FolkMade) do
		pcall(require(SSS.TownsfolkService).Despawn, X.Id)
		pcall(function() X.Post:Destroy() end)
	end
	table.clear(FolkMade)
	SmokeKit.SweepEnemies(Kit.Spot(), SWEEP)
	-- (Task 7) a takedown a failed case left running ends once its victim is gone (an interrupt): wait for its release, so
	-- what it writes on the character is cleared below; then the next case starts off cooldown
	local T0 = os.clock()
	while Char:GetAttribute("TakingDown") and os.clock() - T0 < 2 do task.wait(0.05) end
	local TDS = SSS:FindFirstChild("TakedownService")
	if TDS then pcall(function() require(TDS).Forget(Kit.Player()) end) end
	local C = Kit.Player().Character
	for _, K in ipairs(CLEARED) do C:SetAttribute(K, nil) end
	if Saved then
		for _, K in ipairs(SAVED) do C:SetAttribute(K, Saved[K]) end
	end
	Saved = nil
	PS.SetAuto(true); LS.SetAuto(true)
end

function Kit.Guard(Body)
	local C = Kit.Player().Character
	SmokeKit.Guarded(Kit.Player(), Body, function()
		Saved = {}
		for _, K in ipairs(SAVED) do Saved[K] = C:GetAttribute(K) end
		PS.SetAuto(false); LS.SetAuto(false)
		SmokeKit.TempPart({Name = "Takedown_Floor", Size = FLOOR, CFrame = CFrame.new(Kit.Spot() - Vector3.new(0, FLOOR.Y / 2, 0))})
	end, Kit.Clean)
end

-- ===== the cases' shared helpers (assassinations Task 8 fix round: moved here unchanged from Play_Takedown, so
-- Play_TakedownHard requires them instead of copying them; Play_Takedown takes them from here too) =====
local WorldClock = require(SSS.WorldClock)
local Lighting = game:GetService("Lighting")
local HS = require(SSS.HeatService)
local Progression = require(SSS.ProgressionService)
local function Char() return Kit.Player().Character end

-- a CFrame on the kit's floor X / Z studs from the spot, facing -Z
function Kit.At(X, Z)
	local Pos = Kit.Spot() + Vector3.new(X, 0, Z)
	return CFrame.lookAt(Pos, Pos + Vector3.new(0, 0, -1))
end
-- where the player waits during a body case: 60 studs off on the floor, beyond a Grunt's 30-stud sight and outside
-- every cone the cases use, but within the 80 studs that keep the NPCs updating
Kit.AWAY = Kit.At(60, 10) + Vector3.new(0, 3, 0)
-- the player 4 studs behind the rig at the spot (within CarryRange / GripRange 6), facing it (-Z)
Kit.NEAR = Kit.At(0, 4) + Vector3.new(0, 3, 0)

-- the clock held at Hour while Body runs (Body may move it on), then put back as it was
function Kit.AtHour(Hour, Body)
	local WasHeld = WorldClock.IsHeld() and Lighting.ClockTime
	WorldClock.Hold(Hour)
	local Ok, Err = pcall(Body)
	if WasHeld then WorldClock.Hold(WasHeld) else WorldClock.Release() end
	if not Ok then error(Err, 0) end
end

function Kit.AddBody(Model, Info)
	assert(type(PS.AddBody) == "function", "PerceptionService.AddBody exists")
	PS.AddBody(Model, Info)
	return PS.Bodies[Model]
end

-- a kit Grunt at (X, Z) killed by the test as a takedown would leave it (TakenDownBy set), given 1 s to fall, then
-- registered as a "Dead" body. Returns the body and its Info.
function Kit.DeadBody(X, Z)
	local Body = Kit.Spawn("Grunt", Kit.At(X, Z))
	Body:SetAttribute("TakenDownBy", Kit.Player().Name)
	Body.Humanoid.Health = 0
	task.wait(1)
	return Body, Kit.AddBody(Body, {Kind = "Dead", By = Kit.Player()})
end

-- the weld a carry leaves on the carrier's root (DownedManager's Attach names it)
function Kit.CarryWeld() return Char().HumanoidRootPart:FindFirstChild("DownedWeld") end
-- a kit rig lies free like a real one (Kit.Spawn anchors its root)
function Kit.Free(Rig) Rig.HumanoidRootPart.Anchored = false return Rig end

function Kit.WaitFor(Seconds, Fn)
	local T0 = os.clock()
	while os.clock() - T0 < Seconds do
		if Fn() then return true end
		task.wait(0.05)
	end
	return Fn() and true or false
end

function Kit.Service()
	local M = SSS:FindFirstChild("TakedownService")
	assert(M, "TakedownService exists")
	return require(M)
end
function Kit.Result() return Char():GetAttribute("LastTakedownResult") end
function Kit.Calm() Char():SetAttribute("CombatMode", nil) end -- (the kit puts CombatMode back)
function Kit.Assassinate(Rig) return Kit.Service().Request(Kit.Player(), "Assassinate", Rig) end
function Kit.KnockOut(Rig) return Kit.Service().Request(Kit.Player(), "Knockout", Rig) end
-- the takedown that is running has ended (TakingDown cleared) within Max seconds
function Kit.Finished(Max) return Kit.WaitFor(Max or 2.5, function() return Char():GetAttribute("TakingDown") == nil end) end
-- a kit Grunt at the spot with the player 3 studs straight behind it, Calm; Opts as Kit.Spawn's
function Kit.Behind(Opts)
	local Rig = Kit.Spawn("Grunt", Kit.At(0, 0), Opts)
	Kit.PutBehind(Rig, 3)
	Kit.Calm()
	return Rig
end
-- the save's deed entry, with today's count reset first (pre-flight R17 / D11: the daily cap never decides a case; the
-- hook restores the save)
function Kit.Deed(Id)
	local M = Progression.GetData(Kit.Player()).Morality
	local E = M and M.Deeds[Id]
	if E then E.DayCount = 0 end
	return E
end
-- the law faction of this place's unnamed ground and its jurisdiction (pre-flight R8, written by hand): Ye counts as
-- Lindenmoor (Militia, the Townsfolk's law), the Foundry place as the Foundry (State, the Authority's law)
Kit.LAW = ({[106992859583940] = {Faction = "Townsfolk", J = "Militia"}, [109591196441030] = {Faction = "Authority", J = "State"}})[game.PlaceId]

-- a kit Grunt (Faction set, or none: a bandit) knocked, then gripped to death by the PLAYER (the real Grip path; a
-- player's grip records its own deed, executed_bandit, which is no crime), then found by a patrol at noon. Want: the law's
-- Heat after the find less before the grip (written by hand by each case). Opts.TownsfolkId (Task 8 fix round): the rig
-- also carries that TownsfolkId (an id no TownsfolkService townsperson has, so that service ignores it).
function Kit.GrippedBodyHeat(T, Faction, Want, Opts)
	Opts = Opts or {}
	local LAW, Player = Kit.LAW, Kit.Player()
	assert(LAW, "a law faction for this place")
	Kit.Guard(function() Kit.AtHour(12, function()
		Kit.Deed("executed_bandit")
		local Body = Kit.Spawn("Grunt", Kit.At(0, 0))
		if Faction then Body:SetAttribute("Faction", Faction) end
		if Opts.TownsfolkId then Body:SetAttribute("TownsfolkId", Opts.TownsfolkId) end
		DownedManager.Knock(Body)
		T.True(DownedManager.IsKnocked(Body), "setup: knocked")
		Kit.PutPlayer(Kit.NEAR)
		Kit.Calm()
		local Heat0 = HS.Value(Player, LAW.J)
		T.Eq(DownedManager.Grip(Char(), Body), true, "setup: the player's grip finished")
		T.True(Body.Humanoid.Health <= 0, "setup: the grip killed it")
		task.wait(0.3)
		T.Near(HS.Value(Player, LAW.J) - Heat0, 0, 0.5, "the grip itself raised no Heat (nobody saw it)")
		local Info = PS.Bodies[Body]
		T.True(Info ~= nil and Info.Kind == "Dead" and Info.By == Player, "registered: a Dead body, by the player")
		Kit.PutPlayer(Kit.AWAY)
		task.wait(1)
		Kit.Spawn("Grunt", Kit.At(0, 10)) -- a patrol 10 studs off, facing it (-Z), at noon
		Kit.Run(4)
		T.True(Info ~= nil and Info.Found == true, "the patrol found the body")
		task.wait(0.3)
		T.Near(HS.Value(Player, LAW.J) - Heat0, Want, 1, ("%s Heat when the body is found: %d"):format(LAW.J, Want))
		Kit.Run(2)
		T.Near(HS.Value(Player, LAW.J) - Heat0, Want, 1, "and no more after")
	end) end)
end

return Kit

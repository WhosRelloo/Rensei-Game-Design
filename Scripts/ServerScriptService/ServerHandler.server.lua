local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Framework = Modules.Framework

local WCS = require(Framework.WCS)
local JumpManager = require(Modules.Managers.JumpManager)
local ProgressionService = require(ServerScriptService.ProgressionService)

local Remotes = ReplicatedStorage.Remotes

local InputRemote = Remotes.InputRemote
local JumpRemote = Remotes.JumpRemote
local RequestRemote = Remotes.RequestRemote

local Requests = {}
for _,Module in pairs(script.Requests:GetChildren()) do
	Requests[Module.Name] = require(Module)
end

-- Only these JumpManager functions are client-callable. Previously the client could name ANY
-- function in the module.
local JumpCallable = {
	PlayFX = true,
	ClimbState = true,
	TraversalState = true, -- any MovementState kind (climb, wall run, ledge walk); validated there
	ParkourStamina = true,
}

-- Token bucket per player: Rate requests/second sustained, Burst back to back.
local function Limiter(Rate, Burst)
	local Buckets = {}
	game:GetService("Players").PlayerRemoving:Connect(function(Player)
		Buckets[Player] = nil
	end)
	return function(Player)
		local Now = os.clock()
		local B = Buckets[Player]
		if not B then
			B = {Tokens = Burst, At = Now}
			Buckets[Player] = B
		end
		B.Tokens = math.min(Burst, B.Tokens + (Now - B.At) * Rate)
		B.At = Now
		if B.Tokens < 1 then return false end
		B.Tokens -= 1
		return true
	end
end

local RequestAllowed = Limiter(8, 16)
local JumpAllowed = Limiter(10, 20)

InputRemote.OnServerEvent:Connect(function(Player,InputObject,InputState)
end)

JumpRemote.OnServerEvent:Connect(function(Player,Module,...)
	if type(Module) ~= "string" or not JumpCallable[Module] then return end
	if not JumpAllowed(Player) then return end
	local Ok, Err = pcall(JumpManager[Module], Player, ...)
	if not Ok then warn("JumpRemote", Module, "from", Player.Name, "failed:", Err) end
end)

RequestRemote.OnServerEvent:Connect(function(Player,Module,...)
	if type(Module) ~= "string" or not Requests[Module] then return end
	if not RequestAllowed(Player) then return end
	local Ok, Err = pcall(Requests[Module], Player, ...)
	if not Ok then
		warn("Request", Module, "from", Player.Name, "failed:", Err)
	end
end)

local UIService = require(ServerScriptService.UIService)
local PartyService = require(ServerScriptService.PartyService)
local WorldService = require(ServerScriptService.WorldService)
local DialogueService = require(ServerScriptService.DialogueService)

UIService.Start()
ProgressionService.Start()
require(ReplicatedStorage.Modules.Managers.WeaponManager).Start()
PartyService.Start()
require(ServerScriptService.FlowService).Start() -- menu -> tutorial -> cutscene -> here

WorldService.Start()
DialogueService.Start()
task.spawn(require(ServerScriptService.EnemyService).Start) -- waits for the WCS server first
require(ServerScriptService.AdminService).Start() -- admin panel (F2), AdminConfig decides who
require(ServerScriptService.InvestigationService).Start() -- inspect points (RenseiInspect) + Case Board
require(ServerScriptService.IdentityService).Start() -- Player Identities: encounters, observations, introductions
require(ServerScriptService.PuzzleService).Start() -- per-player mechanisms (RenseiMechanism) + puzzles
require(ServerScriptService.MinigameService).Start() -- Pressure Board, Array Restoration
require(ServerScriptService.MoralityService).Start() -- deeds ledger: conduct, standing, trust, renown
require(ServerScriptService.TrialService).Start() -- alchemy trials (RenseiTrial arenas)
require(ServerScriptService.TrainingService).Start() -- trainer lessons / exercises (mastery training)
require(ServerScriptService.RankService).Start() -- public rank / title / clan for the leaderboard
require(ServerScriptService.SwimService).Start() -- deep water: the Swim traversal state (no fighting / alchemy)
require(ServerScriptService.CombatDirector).Start() -- enemy squads: encounters, the attack token, surround positions
require(ServerScriptService.CompassService).Start() -- the places the top-of-screen compass can point at
script:SetAttribute("Started", os.time())

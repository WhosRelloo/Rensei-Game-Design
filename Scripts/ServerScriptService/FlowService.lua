-- FlowService (Ye = the main game): the last steps of the start flow (owner 2026-10-14):
--   Main Menu -> Customize -> Tutorial -> CUTSCENE -> MAIN GAME.
-- * Live: players arrive here only by an in-flow teleport (TeleportData.Flow = Places.FlowTag)
--   with a created character and the tutorial done. Anyone else (a direct join, a rejoin after a
--   disconnect, an old save) goes to the menu, which sends them on to the right step.
-- * The teleport goes through ServerScriptService.FlowTeleport (retries; a teleport that still
--   fails kicks, since the profile was already released for it).
-- * First arrival after the tutorial: the intro cutscene plays once (IntroRemote ->
--   Modules.UI.IntroCutscene), and Flow.IntroSeen is saved.
-- Studio never teleports; the cutscene still plays there for a profile that hasn't seen it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local FlowTeleport = require(ServerScriptService.FlowTeleport)

local FlowService = {}

local function ToMenu(Player)
	DataManager:Release(Player) -- saved now; the menu loads it next
	FlowTeleport.Send(Player, Places.Menu, {From = "Main"}, function(P)
		P:Kick("Couldn't reach the main menu. Please rejoin.")
	end)
end

local function PlayerAdded(Player)
	local Join = Player:GetJoinData()
	local Data = Join and Join.TeleportData
	local InFlow = type(Data) == "table" and Data.Flow == Places.FlowTag
	local Profile = DataManager:WaitProfile(Player, 20)
	if not Profile then return end
	local D = Profile.Data
	local Ready = D.Identity.CharacterCreated and D.Flow and D.Flow.TutorialDone
	if not RunService:IsStudio() and (not InFlow or not Ready) then
		ToMenu(Player)
		return
	end
	if Ready and not D.Flow.IntroSeen then
		D.Flow.IntroSeen = true
		-- once the character is in, so the cutscene fades in on the world
		local Character = Player.Character or Player.CharacterAdded:Wait()
		task.wait(1)
		if Player.Parent then
			ReplicatedStorage.Remotes.IntroRemote:FireClient(Player, {Name = D.Identity.Name})
		end
	end
end

function FlowService.Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end
end

return FlowService

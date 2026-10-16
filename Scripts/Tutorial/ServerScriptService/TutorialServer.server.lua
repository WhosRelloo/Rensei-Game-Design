-- Rensei tutorial place: the flow step after character creation (owner 2026-10-14):
--   Main Menu -> Customize -> TUTORIAL -> cutscene -> Main game.
-- * Loads the shared profile (FlowData, same store as Ye) and dresses the player in the look
--   chosen at creation (AppearanceService).
-- * Live: a player with no created character goes to the menu.
-- * The tutorial's content ends it with ServerStorage.FinishTutorial:Fire(Player): that saves
--   Flow.TutorialDone and teleports to the main game (the cutscene plays there on arrival).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local FlowData = require(script.Parent.FlowData)
local AppearanceService = require(script.Parent.AppearanceService)
local FlowTeleport = require(script.Parent.FlowTeleport)

FlowData.Start()

local function Teleport(Player, PlaceId, Step)
	if RunService:IsStudio() then
		warn(("[Tutorial] Studio can't teleport. Live, %s would go to the %s place."):format(Player.Name, Step))
		return false
	end
	FlowData.Release(Player) -- saved now (TutorialDone included), so the next place loads it
	-- FlowTeleport retries; if every try fails (now or later) the player rejoins, and the menu sends
	-- them on to the right step from the saved profile
	return FlowTeleport.Send(Player, PlaceId, {From = "Tutorial"}, function(P)
		P:Kick("Couldn't reach the next place. Please rejoin; your progress is saved.")
	end)
end

local function Dress(Player, Character)
	local Profile = FlowData.Wait(Player, 20)
	if not Profile or Player.Character ~= Character then return end
	AppearanceService.ApplyIdentity(Character, Profile.Data.Identity)
end

local function PlayerAdded(Player)
	Player.CharacterAdded:Connect(function(Character) Dress(Player, Character) end)
	if Player.Character then task.spawn(Dress, Player, Player.Character) end
	local Profile = FlowData.Wait(Player, 20)
	if not Profile then return end
	if not Profile.Data.Identity.CharacterCreated then
		Teleport(Player, Places.Menu, "Menu") -- create a character first
	end
end
Players.PlayerAdded:Connect(PlayerAdded)
for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end

-- The tutorial's end. (Fire from the tutorial's own scripts.)
local Finish = ServerStorage:FindFirstChild("FinishTutorial") or Instance.new("BindableEvent")
Finish.Name = "FinishTutorial"
Finish.Parent = ServerStorage
local Finishing = {}
Finish.Event:Connect(function(Player)
	if typeof(Player) ~= "Instance" or not Player:IsA("Player") or Finishing[Player] then return end
	local Profile = FlowData.Get(Player)
	if not Profile then return end
	Finishing[Player] = true
	Profile.Data.Flow = Profile.Data.Flow or {}
	Profile.Data.Flow.TutorialDone = true
	if not Teleport(Player, Places.Main, "Main") then Finishing[Player] = nil end
end)
Players.PlayerRemoving:Connect(function(Player) Finishing[Player] = nil end)

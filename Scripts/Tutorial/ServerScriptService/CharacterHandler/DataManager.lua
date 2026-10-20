-- Tutorial place only: stands in for Ye's CharacterHandler.DataManager so the systems copied
-- from Ye run unchanged. The save is loaded once, by FlowData (same store and key as Ye:
-- ProfileService "PlayerData", "Data" .. UserId). Loading it a second time here would fight
-- FlowData over the session lock. Ye's template data-wipe line is deliberately not carried over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlowData = require(script.Parent.Parent.FlowData)

local DataManager = {}

-- FlowData.Start() is called by TutorialServer.
function DataManager:Initiate() end

function DataManager:GetProfile(Player)
	return FlowData.Get(Player)
end

-- Ye's CharacterHandler waits for the profile before dressing / applying the character (Ye sync 2026-10-20)
function DataManager:WaitProfile(Player, Timeout)
	return FlowData.Wait(Player, Timeout or 30)
end

function DataManager:SendData(Player)
	local Profile = FlowData.Get(Player)
	if Profile then
		ReplicatedStorage.Remotes.DataRemote:FireClient(Player, Profile.Data)
	end
end

return DataManager

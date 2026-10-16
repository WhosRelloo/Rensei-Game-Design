-- FlowTeleport: sends a player to another place of the start flow (Menu, Tutorial, Ye) and copes with
-- a teleport that fails, either at once (TeleportAsync errors) or later (TeleportInitFailed: the
-- server was full, flooded, ...). Failed tries are retried; when every try has failed, OnFail runs
-- (reload the profile, or kick) so a player is never left playing with a released profile.
-- The caller releases the player's profile BEFORE Send, so the next place's ForceLoad gets it at once.
-- Studio can't teleport: callers skip Send there (TeleportAsync errors, which counts as a failure).
-- KEEP THIS FILE THE SAME IN EVERY PLACE.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)

local FlowTeleport = {}
FlowTeleport.Tries = 3 -- teleport attempts before OnFail
FlowTeleport.Wait = 20 -- seconds Send waits for an outcome before reporting "under way"

-- results a retry can't fix
local NoRetry = {
	[Enum.TeleportResult.GameNotFound] = true,
	[Enum.TeleportResult.Unauthorized] = true,
}

local Pending = {} -- [Player] = {PlaceId, Options, Tries, OnFail, Result} (plain table, cleared on leave)

local function Finish(Player, P, Ok, Why)
	if Pending[Player] ~= P then return end
	Pending[Player] = nil
	P.Result = {Ok, Why}
	if not Ok and P.OnFail and Player.Parent then task.spawn(P.OnFail, Player, Why) end
end

local Failed
local function Try(Player, P)
	if Pending[Player] ~= P or not Player.Parent then return end
	P.Tries += 1
	local Ok, Err = pcall(function() TeleportService:TeleportAsync(P.PlaceId, {Player}, P.Options) end)
	if not Ok then Failed(Player, P, tostring(Err), false) end
end

function Failed(Player, P, Why, Final)
	if Pending[Player] ~= P then return end
	warn(("[FlowTeleport] %s -> %d failed (try %d of %d): %s"):format(Player.Name, P.PlaceId, P.Tries, FlowTeleport.Tries, Why))
	if Final or P.Tries >= FlowTeleport.Tries then
		Finish(Player, P, false, Why)
		return
	end
	task.wait(P.Tries * 2)
	Try(Player, P)
end

TeleportService.TeleportInitFailed:Connect(function(Player, Result, Message)
	local P = Pending[Player]
	if not P or Result == Enum.TeleportResult.IsTeleporting then return end
	task.spawn(Failed, Player, P, Result.Name .. ": " .. tostring(Message), NoRetry[Result])
end)

Players.PlayerRemoving:Connect(function(Player)
	local P = Pending[Player]
	if P then Finish(Player, P, true) end -- left = the teleport went through (or they quit)
end)

-- Send the player to PlaceId (yields). Data goes in the teleport data with Flow = Places.FlowTag.
-- Returns true once they've left or the teleport is still under way after FlowTeleport.Wait seconds;
-- false, why when every try failed (OnFail(Player, why) has been called as well). A failure after
-- Send returned still calls OnFail.
function FlowTeleport.Send(Player, PlaceId, Data, OnFail)
	if Pending[Player] then return false, "Already teleporting." end
	local Options = Instance.new("TeleportOptions")
	local TeleportData = table.clone(Data or {})
	TeleportData.Flow = Places.FlowTag
	Options:SetTeleportData(TeleportData)
	local P = {PlaceId = PlaceId, Options = Options, Tries = 0, OnFail = OnFail}
	Pending[Player] = P
	task.spawn(Try, Player, P)
	local Deadline = os.clock() + FlowTeleport.Wait
	while not P.Result and os.clock() < Deadline do task.wait(0.1) end
	if P.Result then return P.Result[1], P.Result[2] end
	return true
end

-- Whether a teleport is in progress for the player.
function FlowTeleport.Busy(Player)
	return Pending[Player] ~= nil
end

return FlowTeleport

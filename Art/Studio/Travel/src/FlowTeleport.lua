-- FlowTeleport: sends a player to another place of the start flow (Menu, Tutorial, Ye) and copes with
-- a teleport that fails, either at once (TeleportAsync errors) or later (TeleportInitFailed: the
-- server was full, flooded, ...). Failed tries are retried; when every try has failed, OnFail runs
-- (reload the profile, or kick) so a player is never left playing with a released profile.
-- The caller releases the player's profile BEFORE Send, so the next place's ForceLoad gets it at once.
-- Studio can't teleport: callers skip Send there (TeleportAsync errors, which counts as a failure).
-- World plan 1 (2026-10-21): SendGroup sends a whole group (a train, a party) in ONE TeleportAsync, so they land
-- on one server (TravelService.Depart). Task 8b: SendGroup's optional Opts.ServerInstanceId sends them to that server
-- (a road party's stragglers follow their party); if it's full or gone, the group falls back to the normal teleport.
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
local Groups = {} -- [Player] = G; G = {PlaceId, Options, Tries, OnFail, Members = {[Player] = true}, Failing} (SendGroup)
local GroupFailed -- defined with SendGroup below; declared up here so the TeleportInitFailed handler can see it

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
	if Result == Enum.TeleportResult.IsTeleporting then return end
	local P = Pending[Player]
	if P then task.spawn(Failed, Player, P, Result.Name .. ": " .. tostring(Message), NoRetry[Result]) return end
	local G = Groups[Player]
	if G then task.spawn(GroupFailed, G, Result.Name .. ": " .. tostring(Message), NoRetry[Result]) end
end)

Players.PlayerRemoving:Connect(function(Player)
	local P = Pending[Player]
	if P then Finish(Player, P, true) end -- left = the teleport went through (or they quit)
	Groups[Player] = nil
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

-- ===== Groups (World plan 1): one TeleportAsync call for a train / party, so they land on one server =====
-- (Groups and GroupFailed are declared at the top, beside Pending, so the event handlers above can see them.)
local function Remaining(G)
	local L = {}
	for P in pairs(G.Members) do if P.Parent then table.insert(L, P) end end
	return L
end
local function TryGroup(G)
	local L = Remaining(G)
	if #L == 0 then return end
	G.Tries += 1
	local Ok, Err = pcall(function() TeleportService:TeleportAsync(G.PlaceId, L, G.Options) end)
	if not Ok then GroupFailed(G, tostring(Err), false) end
end
function GroupFailed(G, Why, Final)
	if G.Failing then return end
	G.Failing = true
	if G.Plain then -- the preferred server is full or gone: the normal teleport instead, with all its tries
		warn(("[FlowTeleport] group -> %d: the preferred server failed (%s); sending them anywhere"):format(G.PlaceId, Why))
		G.Options, G.Plain, G.Tries = G.Plain, nil, 0
		G.Failing = false
		TryGroup(G)
		return
	end
	warn(("[FlowTeleport] group -> %d failed (try %d of %d): %s"):format(G.PlaceId, G.Tries, FlowTeleport.Tries, Why))
	if Final or G.Tries >= FlowTeleport.Tries then
		for P in pairs(G.Members) do
			Groups[P] = nil
			if P.Parent and G.OnFail then task.spawn(G.OnFail, P, Why) end
		end
		return
	end
	task.wait(G.Tries * 2)
	G.Failing = false
	TryGroup(G)
end

-- Whether the player is in a group teleport (SendGroup) that hasn't finished or failed.
function FlowTeleport.InGroup(Player)
	return Groups[Player] ~= nil
end

-- Send every player in List to PlaceId together (does not yield). Same TeleportData rules as Send.
-- Opts (optional): {ServerInstanceId = a JobId of PlaceId} tries that server first.
function FlowTeleport.SendGroup(List, PlaceId, Data, OnFail, Opts)
	local function Make(Instance_)
		local O = Instance.new("TeleportOptions")
		local TeleportData = table.clone(Data or {})
		TeleportData.Flow = Places.FlowTag
		O:SetTeleportData(TeleportData)
		if Instance_ then O.ServerInstanceId = Instance_ end
		return O
	end
	local Join = type(Opts) == "table" and type(Opts.ServerInstanceId) == "string" and Opts.ServerInstanceId ~= "" and Opts.ServerInstanceId or nil
	local Options = Make(Join)
	local G = {PlaceId = PlaceId, Options = Options, Plain = Join and Make(nil) or nil, Tries = 0, OnFail = OnFail, Members = {}}
	for _, P in ipairs(List) do
		if not Pending[P] and not Groups[P] then G.Members[P] = true Groups[P] = G end
	end
	task.spawn(TryGroup, G)
	return G
end

return FlowTeleport

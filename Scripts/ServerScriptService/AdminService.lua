-- AdminService: the server half of the admin panel (AdminUI). Every call is re-checked against
-- AdminConfig here; the client panel is only a front end. One RemoteFunction (Remotes.AdminRemote):
--   "State"                       -> players, enemy types, items, recent log (for the panel)
--   "Run", Command, UserId, Arg   -> ok, message
-- Every command that runs is written to the in-server log (Logs tab) and the server output.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Config = require(ServerScriptService.AdminConfig)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)

local AdminService = {}

local MAX_LOG = 60
local Log = {}
local Admins = {} -- [Player] = true once checked

-- ===== permissions =====
local function Check(Player)
	if Config.Studio and RunService:IsStudio() then return true end
	if Config.Users[Player.UserId] then return true end
	if Config.GroupId and Config.GroupId > 0 then
		local Ok, Rank = pcall(Player.GetRankInGroup, Player, Config.GroupId)
		if Ok and Rank >= (Config.MinRank or 255) then return true end
	end
	return false
end

function AdminService.IsAdmin(Player)
	return Admins[Player] == true
end

-- ===== helpers =====
local function Root(Player)
	local C = Player and Player.Character
	return C and C:FindFirstChild("HumanoidRootPart"), C and C:FindFirstChildOfClass("Humanoid"), C
end

local function Filter(Text, From, To)
	local Ok, Result = pcall(TextService.FilterStringAsync, TextService, Text, From.UserId)
	if not Ok then return nil end
	local Ok2, Out = pcall(function()
		if To then return Result:GetNonChatStringForUserAsync(To.UserId) end
		return Result:GetNonChatStringForBroadcastAsync()
	end)
	return Ok2 and Out or nil
end

local function Number(Arg, Min, Max)
	local N = tonumber(Arg)
	if not N or N ~= N then return nil end
	return math.clamp(N, Min, Max)
end

local function Text(Arg, Max)
	if type(Arg) ~= "string" then return nil end
	Arg = Arg:gsub("^%s+", ""):gsub("%s+$", "")
	if #Arg == 0 then return nil end
	return Arg:sub(1, Max or 120)
end

-- ===== commands =====
-- Target = needs a selected player; each Run returns ok, message.
local Commands = {}

Commands.Heal = {Target = true, Run = function(_, T)
	local _, H = Root(T)
	if not H then return false, "No character" end
	H.Health = H.MaxHealth
	return true, "Healed " .. T.DisplayName
end}

Commands.Kill = {Target = true, Run = function(_, T)
	local _, H = Root(T)
	if not H then return false, "No character" end
	H.Health = 0
	return true, "Killed " .. T.DisplayName
end}

Commands.Respawn = {Target = true, Run = function(_, T)
	T:LoadCharacter()
	return true, "Respawned " .. T.DisplayName
end}

Commands.Bring = {Target = true, Run = function(A, T)
	local From, To = Root(A), Root(T)
	if not (From and To) then return false, "No character" end
	T.Character:PivotTo(From.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0))
	return true, "Brought " .. T.DisplayName
end}

Commands.Goto = {Target = true, Run = function(A, T)
	local From, To = Root(A), Root(T)
	if not (From and To) then return false, "No character" end
	A.Character:PivotTo(To.CFrame * CFrame.new(0, 0, 4))
	return true, "Went to " .. T.DisplayName
end}

Commands.Freeze = {Target = true, Run = function(_, T)
	local R, _, C = Root(T)
	if not R then return false, "No character" end
	local On = not C:GetAttribute("AdminFrozen")
	C:SetAttribute("AdminFrozen", On or nil)
	R.Anchored = On
	return true, (On and "Froze " or "Unfroze ") .. T.DisplayName
end}

Commands.Kick = {Target = true, Run = function(A, T, Arg)
	if T == A then return false, "You can't kick yourself" end
	if Admins[T] and not (Config.Users[A.UserId]) then return false, "Can't kick another admin" end
	local Reason = Text(Arg, 120)
	Reason = Reason and Filter(Reason, A, T) or "Removed by an admin."
	T:Kick(Reason)
	return true, "Kicked " .. T.DisplayName
end}

Commands.GiveMoney = {Target = true, Run = function(_, T, Arg)
	local N = Number(Arg, 1, 10000000)
	if not N then return false, "Enter an amount" end
	if not ProgressionService.GrantMoney(T, N) then return false, "Profile not loaded" end
	return true, ("Gave %d money to %s"):format(N, T.DisplayName)
end}

Commands.GiveExp = {Target = true, Run = function(_, T, Arg)
	local N = Number(Arg, 1, 10000000)
	if not N then return false, "Enter an amount" end
	local Levels = ProgressionService.GrantExp(T, N, "Admin")
	return true, ("Gave %d EXP to %s (+%d levels)"):format(N, T.DisplayName, Levels or 0)
end}

Commands.GiveItem = {Target = true, Run = function(_, T, Arg)
	local Name = Text(Arg, 60)
	if not Name or not ItemData[Name] then return false, "Unknown item" end
	local Profile = DataManager:GetProfile(T)
	if not Profile then return false, "Profile not loaded" end
	local Inventory = Profile.Data.Inventory
	if ItemData[Name].Type == "Consumable" then
		for _, Item in ipairs(Inventory) do
			if Item.ItemName == Name then
				Item.Amount = (Item.Amount or 1) + 1
				DataManager:SendData(T)
				return true, "Gave " .. Name .. " to " .. T.DisplayName
			end
		end
	end
	table.insert(Inventory, {ItemName = Name, ItemID = HttpService:GenerateGUID(false):sub(1, 8), Amount = 1})
	DataManager:SendData(T)
	return true, "Gave " .. Name .. " to " .. T.DisplayName
end}

-- alchemy path: the save's Identity.Affinity ("None" clears it), republished so the slot bar,
-- mobile buttons and the Mastery tree follow straight away
Commands.SetAlchemy = {Target = true, Run = function(_, T, Arg)
	local Registry = require(ReplicatedStorage.Modules.Data.Rensei.Alchemy)
	local Path = Text(Arg, 20)
	if Path ~= "None" and not table.find(Registry.Affinities, Path) then return false, "Unknown alchemy path" end
	local Profile = DataManager:GetProfile(T)
	if not Profile then return false, "Profile not loaded" end
	local Identity = Profile.Data.Identity
	if type(Identity) ~= "table" then return false, "No character identity" end
	Identity.Affinity = Path == "None" and "" or Path
	local AlchemyService = require(ServerScriptService.AlchemyService)
	AlchemyService.PublishAffinity(T)
	ProgressionService.Sync(T)
	local Now = AlchemyService.AffinityOf(T)
	return true, ("%s's alchemy: %s"):format(T.DisplayName, Now or "none")
end}

-- alchemist rank (RankService): raise grants every rank up to N, each checked (level, the rank
-- below); lower takes rank N+1 and above away. Rank 4 is WIP and can't be set.
Commands.SetRank = {Target = true, Run = function(_, T, Arg)
	local N = Number(Arg, 1, 3)
	if not N or N % 1 ~= 0 then return false, "Rank 1-3 (4 is WIP)" end
	local RankService = require(ServerScriptService.RankService)
	local Now = RankService.RankOf(T)
	if not Now then return false, "Profile not loaded" end
	if N < Now then
		RankService.Demote(T, N + 1)
	else
		for R = Now + 1, N do
			local Ok, Why = RankService.Promote(T, R)
			if not Ok then return false, Why end
		end
	end
	return true, ("%s is rank %d"):format(T.DisplayName, RankService.RankOf(T) or 0)
end}

-- world
local AdminSpawns = {}
Commands.SpawnEnemy = {Run = function(A, _, Arg)
	local Type = Text(Arg, 40)
	if not Type or not Tuning.Enemies[Type] then return false, "Unknown enemy type" end
	local R = Root(A)
	if not R then return false, "No character" end
	if #AdminSpawns >= 12 then return false, "Too many admin spawns (clear them first)" end
	local Part = Instance.new("Part")
	Part.Name = "AdminSpawn"
	Part.Anchored, Part.CanCollide, Part.CanQuery, Part.CanTouch = true, false, false, false
	Part.Transparency = 1
	Part.Size = Vector3.new(2, 1, 2)
	Part.CFrame = R.CFrame * CFrame.new(0, 0, -10) * CFrame.Angles(0, math.pi, 0)
	Part:SetAttribute("EnemyType", Type)
	Part:SetAttribute("RespawnTime", 1e9) -- admin spawns never come back
	Part.Parent = workspace
	local Rig = require(ServerScriptService.EnemyService).Spawn(Part)
	if not Rig then Part:Destroy() return false, "Spawn failed" end
	table.insert(AdminSpawns, Part)
	Rig.Humanoid.Died:Once(function()
		task.delay(6, function()
			local I = table.find(AdminSpawns, Part)
			if I then table.remove(AdminSpawns, I) end
			Part:Destroy()
		end)
	end)
	return true, "Spawned " .. (Tuning.Enemies[Type].DisplayName or Type)
end}

Commands.KillEnemies = {Run = function()
	local N = 0
	for Rig in pairs(require(ServerScriptService.EnemyService).Active) do
		local H = Rig:FindFirstChildOfClass("Humanoid")
		if H and H.Health > 0 then H.Health = 0 N += 1 end
	end
	return true, ("Killed %d enemies"):format(N)
end}

Commands.ClearSpawns = {Run = function()
	local Active = require(ServerScriptService.EnemyService).Active
	local N = 0
	for Rig, E in pairs(Active) do
		if E.Home and E.Home.Name == "AdminSpawn" then
			Active[Rig] = nil
			pcall(function() E.WCS:Destroy() end)
			Rig:Destroy()
			N += 1
		end
	end
	for _, Part in ipairs(AdminSpawns) do Part:Destroy() end
	table.clear(AdminSpawns)
	return true, ("Cleared %d admin spawns"):format(N)
end}

Commands.Time = {Run = function(_, _, Arg)
	local N = Number(Arg, 0, 24)
	if not N then return false, "Enter an hour (0-24)" end
	Lighting.ClockTime = N
	return true, ("Time set to %.1f"):format(N)
end}

Commands.Announce = {Run = function(A, _, Arg)
	local Msg = Text(Arg, 150)
	if not Msg then return false, "Enter a message" end
	Msg = Filter(Msg, A)
	if not Msg then return false, "Message couldn't be filtered" end
	UIService.NotifyAll("Banner", {Text = Msg})
	return true, "Announced"
end}

-- self
Commands.God = {Run = function(A)
	local _, H, C = Root(A)
	if not C then return false, "No character" end
	local On = not C:GetAttribute("AdminGod")
	C:SetAttribute("AdminGod", On or nil)
	if On then H.Health = H.MaxHealth end
	return true, On and "God mode on" or "God mode off"
end}

Commands.Speed = {Run = function(A, _, Arg)
	local _, _, C = Root(A)
	if not C then return false, "No character" end
	local N = Number(Arg, 0.5, 4)
	if not N then return false, "Enter a multiplier (0.5-4)" end
	C:SetAttribute("SpeedMultiplier", N ~= 1 and N or nil)
	return true, ("Speed x%.2f"):format(N)
end}

-- ===== state for the panel =====
local function State()
	local List = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local _, H, C = Root(P)
		table.insert(List, {
			UserId = P.UserId, Name = P.Name, DisplayName = P.DisplayName,
			Level = P:GetAttribute("Level") or 0, Admin = Admins[P] == true,
			Health = H and math.floor(H.Health) or 0, MaxHealth = H and math.floor(H.MaxHealth) or 0,
			Frozen = C and C:GetAttribute("AdminFrozen") == true, God = C and C:GetAttribute("AdminGod") == true,
			InCombat = C and C:GetAttribute("InCombat") == true,
			Affinity = P:GetAttribute("Affinity") or "None",
			Rank = P:GetAttribute("Rank"), Title = P:GetAttribute("Title"),
		})
	end
	table.sort(List, function(X, Y) return X.DisplayName:lower() < Y.DisplayName:lower() end)
	local Enemies = {}
	for Type, Def in pairs(Tuning.Enemies) do table.insert(Enemies, {Type = Type, Name = Def.DisplayName or Type, Level = Def.Level}) end
	table.sort(Enemies, function(X, Y) return (X.Level or 0) < (Y.Level or 0) end)
	local Items = {}
	for Name, Info in pairs(ItemData) do
		if type(Info) == "table" then table.insert(Items, {Name = Name, Type = Info.Type}) end
	end
	table.sort(Items, function(X, Y) return X.Name < Y.Name end)
	local ActiveCount = 0
	for _ in pairs(require(ServerScriptService.EnemyService).Active) do ActiveCount += 1 end
	local Paths = {"None"}
	for _, A in ipairs(require(ReplicatedStorage.Modules.Data.Rensei.Alchemy).Affinities) do table.insert(Paths, A) end
	return {Players = List, Enemies = Enemies, Items = Items, Log = Log, ClockTime = Lighting.ClockTime, Affinities = Paths,
		ActiveEnemies = ActiveCount, AdminSpawns = #AdminSpawns}
end

local function Record(A, Name, T, Arg, Message)
	table.insert(Log, 1, {At = os.time(), Admin = A.DisplayName, Command = Name,
		Target = T and T.DisplayName or nil, Arg = Arg ~= nil and tostring(Arg):sub(1, 40) or nil, Message = Message})
	if #Log > MAX_LOG then table.remove(Log) end
	print(("[Admin] %s: %s%s%s -> %s"):format(A.Name, Name, T and (" " .. T.Name) or "",
		Arg ~= nil and (" " .. tostring(Arg):sub(1, 40)) or "", Message))
end

local Last = {}
local function Handle(Player, Kind, Name, UserId, Arg)
	if not Admins[Player] then return false, "Not an admin" end
	if Kind == "State" then return State() end
	if Kind ~= "Run" or type(Name) ~= "string" then return false, "Bad request" end
	local Cmd = Commands[Name]
	if not Cmd then return false, "Unknown command" end
	local Now = os.clock()
	if Last[Player] and Now - Last[Player] < 0.2 then return false, "Slow down" end
	Last[Player] = Now
	local Target
	if Cmd.Target then
		Target = type(UserId) == "number" and Players:GetPlayerByUserId(UserId)
		if not Target then return false, "Pick a player first" end
	end
	if Arg ~= nil and type(Arg) ~= "string" and type(Arg) ~= "number" then return false, "Bad argument" end
	local Ok, Done, Message = pcall(Cmd.Run, Player, Target, Arg)
	if not Ok then
		warn("[Admin]", Name, "failed:", Done)
		return false, "Command failed"
	end
	if Done then Record(Player, Name, Target, Arg, Message) end
	return Done, Message
end

function AdminService.Start()
	local Remote = Instance.new("RemoteFunction")
	Remote.Name = "AdminRemote"
	Remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Remote.OnServerInvoke = Handle

	local function Added(Player)
		if Check(Player) then
			Admins[Player] = true
			Player:SetAttribute("RenseiAdmin", true) -- tells the client to build the panel (F2)
		end
	end
	Players.PlayerAdded:Connect(Added)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(Added, P) end
	Players.PlayerRemoving:Connect(function(P) Admins[P] = nil Last[P] = nil end)
end

return AdminService

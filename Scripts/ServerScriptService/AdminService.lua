-- AdminService: the server half of the admin panel (AdminUI). Every call is re-checked against
-- AdminConfig here; the client panel is only a front end. One RemoteFunction (Remotes.AdminRemote):
--   "State"                       -> players, enemy types, items, recent log (for the panel)
--   "Inspect", UserId              -> a summary of that player's save (Players tab)
--   "Run", Command, UserId, Arg   -> ok, message
-- Every command that runs is written to the staff log: the server output, a DataStore list of the last
-- LOG_KEEP actions across all servers (Logs tab), and the Discord staff channel when the experience has the
-- STAFF_WEBHOOK secret (admin pass 2026-10-20). A non-admin calling the remote is reported there once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")

local Config = require(ServerScriptService.AdminConfig)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)

local AdminService = {}

local LOG_KEEP = 200 -- staff actions kept in the DataStore (all servers, newest first)
local Log = {} -- what the Logs tab shows: the stored list plus anything not saved yet, newest first
local Admins = {} -- [Player] = true once checked

-- ===== permissions =====
-- Only the accounts in AdminConfig.Users, everywhere (owner 2026-10-19). Re-checked on every call.
local function Check(Player)
	return Config.Users[Player.UserId] == true
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

-- (downed crawl fix round 2, 2026-10-27) a deliberate move of a player's character: DownedManager's crawl clamp starts
-- again from the new spot, else it would put a knocked player back where they were
local function Rebased(C)
	if C then pcall(function() require(game:GetService("ReplicatedStorage").Modules.Managers.DownedManager).RebaseCrawl(C) end) end
end

Commands.Bring = {Target = true, Run = function(A, T)
	local From, To = Root(A), Root(T)
	if not (From and To) then return false, "No character" end
	T.Character:PivotTo(From.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0))
	Rebased(T.Character)
	return true, "Brought " .. T.DisplayName
end}

Commands.Goto = {Target = true, Run = function(A, T)
	local From, To = Root(A), Root(T)
	if not (From and To) then return false, "No character" end
	A.Character:PivotTo(To.CFrame * CFrame.new(0, 0, 4))
	Rebased(A.Character)
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
	if Check(T) then return false, "Can't kick another admin" end
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

-- through ItemService.Give, so the bag limits hold (60 entries, 999 per stack); it used to add past both
Commands.GiveItem = {Target = true, Run = function(_, T, Arg)
	local Name = Text(Arg, 60)
	if not Name or not ItemData[Name] then return false, "Unknown item" end
	if not DataManager:GetProfile(T) then return false, "Profile not loaded" end
	if not require(ServerScriptService.ItemService).Give(T, Name, 1) then
		return false, T.DisplayName .. "'s bag is full (60 entries / 999 a stack)"
	end
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

-- Region Foundation Task 2: an hour holds the world clock there; "run" lets it follow real time again
Commands.Time = {Run = function(_, _, Arg)
	local WorldClock = require(ServerScriptService.WorldClock)
	if type(Arg) == "string" and Arg:lower():match("^%s*run%s*$") then
		WorldClock.Release()
		return true, "Time runs again"
	end
	local N = Number(Arg, 0, 24)
	if not N then return false, "Enter an hour (0-24), or run" end
	WorldClock.Hold(N)
	return true, ("Time held at %.1f (\"run\" lets it run)"):format(N)
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

-- Fly / noclip: the server only flips the attribute; the admin's own client (AdminUI) does the moving
local function SelfToggle(Attribute, Label)
	return {Run = function(A)
		local _, _, C = Root(A)
		if not C then return false, "No character" end
		local On = not C:GetAttribute(Attribute)
		C:SetAttribute(Attribute, On or nil)
		return true, Label .. (On and " on" or " off")
	end}
end
Commands.Fly = SelfToggle("AdminFly", "Fly")
Commands.Noclip = SelfToggle("AdminNoclip", "Noclip")

-- areas: the parts tagged RenseiArea (WorldService), by AreaName
local function Areas()
	local List = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiArea")) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) then
			local Name = P:GetAttribute("AreaName") or P.Name
			if not List[Name] then List[Name] = P end
		end
	end
	return List
end

Commands.TeleportArea = {Run = function(A, _, Arg)
	local Name = Text(Arg, 60)
	local Part = Name and Areas()[Name]
	if not Part then return false, "Unknown area" end
	local R = Root(A)
	if not R then return false, "No character" end
	-- the area's centre, dropped onto whatever solid ground is below the top of its volume
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {A.Character}
	Params.RespectCanCollide = true
	local Top = Part.Position + Vector3.new(0, Part.Size.Y / 2, 0)
	local Hit = workspace:Raycast(Top, Vector3.new(0, -(Part.Size.Y + 300), 0), Params)
	A.Character:PivotTo(CFrame.new((Hit and Hit.Position or Part.Position) + Vector3.new(0, 4, 0)))
	Rebased(A.Character)
	return true, "Teleported to " .. Name
end}

-- ===== testing helpers =====
local function Resources() return require(ReplicatedStorage.Modules.Managers.ResourceManager) end

Commands.Refill = {Target = true, Run = function(_, T)
	local _, _, C = Root(T)
	if not C then return false, "No character" end
	local RM = Resources()
	for _, Name in ipairs({"Posture", "Stamina", "Meter"}) do
		local Max = RM.Max(C, Name)
		if Max then RM.Set(C, Name, Max) end
	end
	return true, "Refilled posture, stamina and meter for " .. T.DisplayName
end}

-- every server-side move cooldown is a "...ReadyAt" attribute on the character (CooldownUI, AlchemyService);
-- the dash's own timer lives on the client and isn't touched
Commands.ClearCooldowns = {Target = true, Run = function(_, T)
	local _, _, C = Root(T)
	if not C then return false, "No character" end
	local N = 0
	for Name in pairs(C:GetAttributes()) do
		if Name:match("ReadyAt$") or Name == "ParryWhiffUntil" then
			C:SetAttribute(Name, nil)
			N += 1
		end
	end
	return true, ("Cleared %d cooldowns on %s"):format(N, T.DisplayName)
end}

Commands.GiveMastery = {Target = true, Run = function(_, T, Arg)
	local N = Number(Arg, 1, 100)
	if not N or N % 1 ~= 0 then return false, "Enter 1-100 points" end
	local Profile = DataManager:GetProfile(T)
	local Mastery = Profile and Profile.Data.Mastery
	if type(Mastery) ~= "table" then return false, "Profile not loaded" end
	Mastery.Unspent = (Mastery.Unspent or 0) + N
	pcall(function() require(ServerScriptService.SkillTreeService).Publish(T) end)
	ProgressionService.Sync(T)
	return true, ("Gave %d Mastery points to %s (%d unspent)"):format(N, T.DisplayName, Mastery.Unspent)
end}

-- Snapshot / Restore: one saved copy of a player's current save slot (DataStore RenseiAdminSnapshots), so a
-- test or a mistake can be rolled back. Restore swaps the save in place and sends the player back to rejoin:
-- the profile is written when it's released, and a rejoin reloads every system from it.
local SnapStore = DataStoreService:GetDataStore("RenseiAdminSnapshots")
local function Copy(T)
	if type(T) ~= "table" then return T end
	local C = {}
	for K, V in pairs(T) do C[K] = Copy(V) end
	return C
end
local function SlotOf(P)
	local Ok, Key, Slot = pcall(require(ServerScriptService.SlotAccount).ProfileKey, P.UserId)
	if not Ok then return nil end
	return Key, Slot
end

Commands.Snapshot = {Target = true, Run = function(A, T)
	local Profile = DataManager:GetProfile(T)
	if not Profile then return false, "Profile not loaded" end
	local Key, Slot = SlotOf(T)
	local Ok, Err = pcall(SnapStore.SetAsync, SnapStore, tostring(T.UserId), {At = os.time(), By = A.Name, Key = Key, Slot = Slot, Data = Copy(Profile.Data)})
	if not Ok then return false, "Snapshot failed: " .. tostring(Err):sub(1, 80) end
	return true, ("Saved a snapshot of %s (slot %s)"):format(T.DisplayName, tostring(Slot or "?"))
end}

Commands.Restore = {Target = true, Run = function(A, T)
	local Profile = DataManager:GetProfile(T)
	if not Profile then return false, "Profile not loaded" end
	local Ok, Snap = pcall(SnapStore.GetAsync, SnapStore, tostring(T.UserId))
	if not Ok then return false, "Couldn't read the snapshot" end
	if type(Snap) ~= "table" or type(Snap.Data) ~= "table" then return false, "No snapshot of " .. T.DisplayName end
	if Snap.Key ~= SlotOf(T) then return false, "That snapshot is from another save slot" end
	local Data = Profile.Data
	for K in pairs(Data) do Data[K] = nil end
	for K, V in pairs(Copy(Snap.Data)) do Data[K] = V end
	local When = os.date("!%Y-%m-%d %H:%M UTC", Snap.At)
	task.delay(0.5, function()
		if T.Parent then T:Kick("An admin restored your save to " .. When .. ". Rejoin to continue.") end
	end)
	return true, ("Restored %s to the snapshot from %s; they were sent back to rejoin"):format(T.DisplayName, When)
end}

-- ===== moderation =====
Commands.Warn = {Target = true, Run = function(A, T, Arg)
	local Msg = Text(Arg, 150)
	if not Msg then return false, "Enter a warning" end
	Msg = Filter(Msg, A, T)
	if not Msg then return false, "Message couldn't be filtered" end
	UIService.Notify(T, "Banner", {Text = "Staff warning: " .. Msg})
	return true, ("Warned %s: %s"):format(T.DisplayName, Msg)
end}

-- Bans use Roblox's ban API (every server of the experience, alt accounts included). Our own list of them
-- (DataStore RenseiAdminBans, "List") is what the Mod tab shows; Roblox has no call that lists bans.
local BanStore = DataStoreService:GetDataStore("RenseiAdminBans")
local Bans = {} -- [tostring(UserId)] = {Name, Reason, Hours, At, By}
local function LoadBans()
	local Ok, List = pcall(BanStore.GetAsync, BanStore, "List")
	if Ok and type(List) == "table" then Bans = List end
end
local function SaveBans(Change)
	return pcall(BanStore.UpdateAsync, BanStore, "List", function(Old)
		Old = type(Old) == "table" and Old or {}
		Change(Old)
		Bans = Old
		return Old
	end)
end
local function NameOf(UserId)
	local P = Players:GetPlayerByUserId(UserId)
	if P then return P.Name end
	local Ok, Name = pcall(Players.GetNameFromUserIdAsync, Players, UserId)
	return Ok and Name or ("User " .. UserId)
end
local function ValidUserId(UserId)
	return type(UserId) == "number" and UserId > 0 and UserId % 1 == 0 and UserId < 2 ^ 53
end

-- Arg = "hours|reason" (0 or blank hours = permanent); UserId = the selected player or one typed in
Commands.Ban = {AnyUser = true, Run = function(A, _, Arg, UserId)
	if not ValidUserId(UserId) then return false, "Pick a player or type a UserId" end
	if Config.Users[UserId] then return false, "Admins can't be banned" end
	local HoursText, Reason = tostring(Arg or ""):match("^%s*([%d%.]*)%s*|(.*)$")
	local Hours = math.clamp(tonumber(HoursText) or 0, 0, 24 * 365)
	Reason = Text(Reason, 120)
	if not Reason then return false, "Enter a reason" end
	local Shown = Filter(Reason, A) or "Banned by staff."
	local Ok, Err = pcall(Players.BanAsync, Players, {
		UserIds = {UserId}, ApplyToUniverse = true,
		Duration = Hours > 0 and math.floor(Hours * 3600) or -1,
		DisplayReason = Shown, PrivateReason = ("%s (by %s)"):format(Reason, A.Name),
		ExcludeAltAccounts = false,
	})
	if not Ok then return false, "Ban failed: " .. tostring(Err):sub(1, 90) end
	local Name = NameOf(UserId)
	SaveBans(function(L) L[tostring(UserId)] = {Name = Name, Reason = Reason, Hours = Hours, At = os.time(), By = A.Name} end)
	return true, ("Banned %s (%d) %s: %s"):format(Name, UserId, Hours > 0 and ("for " .. Hours .. " h") or "permanently", Reason)
end}

Commands.Unban = {AnyUser = true, Run = function(_, _, _, UserId)
	if not ValidUserId(UserId) then return false, "Type a UserId" end
	local Ok, Err = pcall(Players.UnbanAsync, Players, {UserIds = {UserId}, ApplyToUniverse = true})
	if not Ok then return false, "Unban failed: " .. tostring(Err):sub(1, 90) end
	local Name = (Bans[tostring(UserId)] and Bans[tostring(UserId)].Name) or NameOf(UserId)
	SaveBans(function(L) L[tostring(UserId)] = nil end)
	return true, ("Unbanned %s (%d)"):format(Name, UserId)
end}

-- ===== inspect =====
local function Count(T)
	local N = 0
	if type(T) == "table" then for _ in pairs(T) do N += 1 end end
	return N
end
local function Inspect(UserId)
	local T = type(UserId) == "number" and Players:GetPlayerByUserId(UserId)
	if not T then return nil end
	local Profile = DataManager:GetProfile(T)
	if not Profile then return {UserId = UserId, Loaded = false} end
	local D = Profile.Data
	local Id = type(D.Identity) == "table" and D.Identity or {}
	local _, Slot = SlotOf(T)
	local SnapAt
	local Ok, Snap = pcall(SnapStore.GetAsync, SnapStore, tostring(T.UserId))
	if Ok and type(Snap) == "table" then SnapAt = Snap.At end
	return {
		UserId = UserId, Loaded = true, Slot = Slot, Schema = D.SchemaVersion,
		Character = Id.Name ~= "" and Id.Name or nil, Origin = Id.Origin, Affinity = Id.Affinity ~= "" and Id.Affinity or "None",
		Level = D.Level, Exp = D.Exp, Money = D.Money, StatPoints = D.StatPoints,
		Inventory = type(D.Inventory) == "table" and #D.Inventory or 0,
		Mastery = type(D.Mastery) == "table" and D.Mastery.Unspent or 0, MasteryStage = type(D.Mastery) == "table" and D.Mastery.Stage or 0,
		QuestsActive = Count(type(D.Quests) == "table" and D.Quests.Active), QuestsDone = Count(type(D.Quests) == "table" and D.Quests.Completed),
		Areas = Count(D.Areas), Codex = Count(D.Codex), Renown = type(D.Morality) == "table" and D.Morality.Renown or 0,
		Automail = type(D.Automail) == "table" and D.Automail.Installed == true, Rank = T:GetAttribute("Rank"),
		SnapshotAt = SnapAt,
	}
end

-- ===== staff log: DataStore + Discord =====
local LogStore = DataStoreService:GetDataStore("RenseiStaffLog")
local Pending = {} -- recorded here, not yet in the DataStore (oldest first)
local LogStatus = "not loaded yet"
local ServerTag = RunService:IsStudio() and "Studio" or (game.JobId ~= "" and game.JobId:sub(1, 8) or "?")

local function MergeLog(Stored)
	local New = {}
	for I = #Pending, 1, -1 do table.insert(New, Pending[I]) end
	for _, E in ipairs(type(Stored) == "table" and Stored or {}) do
		if #New >= LOG_KEEP then break end
		table.insert(New, E)
	end
	Log = New
end

local function LoadLog()
	local Ok, Stored = pcall(LogStore.GetAsync, LogStore, "Recent")
	if Ok then
		MergeLog(Stored)
		LogStatus = "saved"
	else
		LogStatus = "couldn't load: " .. tostring(Stored):sub(1, 60)
	end
end

local function FlushLog()
	if #Pending == 0 then return end
	local Batch = Pending
	Pending = {}
	local Ok, Stored = pcall(LogStore.UpdateAsync, LogStore, "Recent", function(Old)
		local New = {}
		for I = #Batch, 1, -1 do table.insert(New, Batch[I]) end
		for _, E in ipairs(type(Old) == "table" and Old or {}) do
			if #New >= LOG_KEEP then break end
			table.insert(New, E)
		end
		return New
	end)
	if Ok then
		MergeLog(Stored)
		LogStatus = "saved " .. os.date("!%H:%M:%S UTC")
	else
		-- keep them for the next try, ahead of anything recorded since
		for I = #Batch, 1, -1 do table.insert(Pending, 1, Batch[I]) end
		LogStatus = "save failed, retrying: " .. tostring(Stored):sub(1, 60)
	end
end

-- Discord: STAFF_WEBHOOK is an experience secret (Creator Dashboard > Secrets, allowed domain discord.com).
-- Lines are batched (one post every DISCORD_EVERY s, Discord allows 30 a minute) and never ping anyone.
local DISCORD_EVERY = 2.5
local OUTBOX_MAX = 100
local Webhook = nil
local DiscordStatus = "OFF"
local Outbox = {}

local function LoadWebhook()
	local Ok, Secret = pcall(HttpService.GetSecret, HttpService, "STAFF_WEBHOOK")
	if Ok and Secret then
		Webhook = Secret
		DiscordStatus = "ON"
	else
		DiscordStatus = "OFF: no STAFF_WEBHOOK secret" .. (RunService:IsStudio() and " (Studio can't read the live secrets)" or "")
	end
end

local function Discord(Line)
	if not Webhook then return end
	if #Outbox >= OUTBOX_MAX then table.remove(Outbox, 1) end
	table.insert(Outbox, Line:sub(1, 400))
end

local function FlushDiscord()
	if not Webhook or #Outbox == 0 then return end
	local Lines, Length = {}, 0
	while #Outbox > 0 and #Lines < 15 and Length + #Outbox[1] + 1 <= 1900 do
		local L = table.remove(Outbox, 1)
		table.insert(Lines, L)
		Length += #L + 1
	end
	local Body = HttpService:JSONEncode({username = "Rensei Staff Log", content = table.concat(Lines, "\n"), allowed_mentions = {parse = {}}})
	local Ok, Res = pcall(HttpService.RequestAsync, HttpService, {
		Url = Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = Body,
	})
	if Ok and Res.Success then
		DiscordStatus = "ON"
	elseif Ok and Res.StatusCode == 429 then
		for I = #Lines, 1, -1 do table.insert(Outbox, 1, Lines[I]) end -- rate limited: try again
	else
		DiscordStatus = "ON, last post failed: " .. (Ok and tostring(Res.StatusCode) or tostring(Res):sub(1, 60))
	end
end

-- ===== state for the panel =====
local HeartbeatAvg = 1 / 60
RunService.Heartbeat:Connect(function(Dt) HeartbeatAvg += (Dt - HeartbeatAvg) * 0.05 end)

local function State()
	local List = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local _, H, C = Root(P)
		local PingOk, Ping = pcall(P.GetNetworkPing, P)
		table.insert(List, {
			UserId = P.UserId, Name = P.Name, DisplayName = P.DisplayName,
			Level = P:GetAttribute("Level") or 0, Admin = Check(P), Ping = PingOk and math.floor(Ping * 1000) or nil,
			Fly = C and C:GetAttribute("AdminFly") == true, Noclip = C and C:GetAttribute("AdminNoclip") == true,
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
	local AreaNames = {}
	for Name in pairs(Areas()) do table.insert(AreaNames, Name) end
	table.sort(AreaNames)
	local BanList = {}
	for Id, B in pairs(Bans) do
		if type(B) == "table" then
			local Ends = (B.Hours or 0) > 0 and (B.At or 0) + B.Hours * 3600 or nil
			table.insert(BanList, {UserId = tonumber(Id), Name = B.Name, Reason = B.Reason, Hours = B.Hours, At = B.At, By = B.By,
				Expired = Ends ~= nil and os.time() >= Ends})
		end
	end
	table.sort(BanList, function(X, Y) return (X.At or 0) > (Y.At or 0) end)
	return {Players = List, Enemies = Enemies, Items = Items, Log = Log, ClockTime = Lighting.ClockTime, Affinities = Paths,
		ActiveEnemies = ActiveCount, AdminSpawns = #AdminSpawns, Areas = AreaNames, Bans = BanList,
		Server = {
			FPS = math.floor(workspace:GetRealPhysicsFPS() + 0.5), HeartbeatMs = math.floor(HeartbeatAvg * 10000 + 0.5) / 10,
			MemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()), Uptime = math.floor(time()),
			Players = #Players:GetPlayers(), MaxPlayers = Players.MaxPlayers, PlaceVersion = game.PlaceVersion,
			Tag = ServerTag, Discord = DiscordStatus, LogStatus = LogStatus, Unsaved = #Pending,
		}}
end

local function Record(A, Name, T, Arg, Message)
	local Entry = {At = os.time(), Admin = A.DisplayName, AdminId = A.UserId, Command = Name,
		Target = T and T.DisplayName or nil, Arg = Arg ~= nil and tostring(Arg):sub(1, 40) or nil,
		Message = tostring(Message or ""):sub(1, 160), Server = ServerTag}
	table.insert(Pending, Entry)
	table.insert(Log, 1, Entry)
	if #Log > LOG_KEEP then table.remove(Log) end
	print(("[Admin] %s: %s%s%s -> %s"):format(A.Name, Name, T and (" " .. T.Name) or "",
		Arg ~= nil and (" " .. tostring(Arg):sub(1, 40)) or "", tostring(Message)))
	Discord(("`[%s]` **%s** %s: %s"):format(ServerTag, A.Name, Name, tostring(Message or "")))
end

local Last = {}
local Denied = {} -- [Player] = true once a non-admin call was reported
local function Handle(Player, Kind, Name, UserId, Arg)
	if not Check(Player) then
		Admins[Player] = nil
		if not Denied[Player] then
			Denied[Player] = true
			warn(("[Admin] non-admin %s (%d) called the admin remote"):format(Player.Name, Player.UserId))
			Discord(("`[%s]` :warning: non-admin **%s** (%d) called the admin remote"):format(ServerTag, Player.Name, Player.UserId))
		end
		return false, "Not an admin"
	end
	if Kind == "State" then return State() end
	if Kind == "Inspect" then return Inspect(UserId) end
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
	local Ok, Done, Message = pcall(Cmd.Run, Player, Target, Arg, Cmd.AnyUser and UserId or nil)
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
	Players.PlayerRemoving:Connect(function(P) Admins[P] = nil Last[P] = nil Denied[P] = nil end)

	-- staff log + bans + Discord
	LoadWebhook()
	task.spawn(LoadLog)
	task.spawn(LoadBans)
	task.spawn(function()
		local Since = 0
		while true do
			task.wait(DISCORD_EVERY)
			FlushDiscord()
			Since += DISCORD_EVERY
			if Since >= 15 then
				Since = 0
				FlushLog()
				LoadBans() -- other servers' bans
			end
		end
	end)
	game:BindToClose(function()
		FlushLog()
		FlushDiscord()
	end)
end

return AdminService

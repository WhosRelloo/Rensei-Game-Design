-- WorldService: area discovery and NPC defeats.
--   Areas: any BasePart tagged "RenseiArea" (attributes AreaName, Description) is a region. The
--     first time a player stands inside it the discovery popup plays and it is saved.
--   Defeats: when a non-player humanoid in workspace.World.Live dies, the player who hit it last
--     (within DEFEAT_CREDIT_SECONDS) is credited: EXP, money, Mastery "Defeat" training, codex
--     entry and quest progress. Rewards read attributes on the NPC model:
--       Level, ExpReward, MoneyReward, CodexEntry, DisplayName, QuestTarget.
--     PROPOSAL: with no ExpReward set, EXP = 25 * Level.
--     Credit(Victim, Player) also credits a named player directly (MoralityService: a knocked
--     enemy carried in alive counts as the defeat). A victim is only ever credited once.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProgressionService = require(ServerScriptService.ProgressionService)
local QuestService = require(ServerScriptService.QuestService)
local UIService = require(ServerScriptService.UIService)

local AREA_TAG = "RenseiArea"
-- PROPOSAL: a player stays "in combat" this long after dealing or taking any attack.
local COMBAT_SECONDS = 12
local DEFEAT_CREDIT_SECONDS = 15

local WorldService = {}

local LastHit = setmetatable({}, {__mode = "k"}) -- [VictimModel] = {Player, Time}
local Watched = setmetatable({}, {__mode = "k"})

local function Inside(Part, Position)
	local Local = Part.CFrame:PointToObjectSpace(Position)
	local Half = Part.Size / 2
	return math.abs(Local.X) <= Half.X and math.abs(Local.Y) <= Half.Y and math.abs(Local.Z) <= Half.Z
end

function WorldService.AreaAt(Position)
	for _, Part in ipairs(CollectionService:GetTagged(AREA_TAG)) do
		if Part:IsA("BasePart") and Inside(Part, Position) then return Part end
	end
end

local function CheckAreas()
	for _, Player in ipairs(Players:GetPlayers()) do
		local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		local Data = Root and ProgressionService.GetData(Player)
		if Data then
			local Part = WorldService.AreaAt(Root.Position)
			local Name = Part and (Part:GetAttribute("AreaName") or Part.Name)
			if Name ~= Player:GetAttribute("Area") then
				Player:SetAttribute("Area", Name)
				if Name then
					QuestService.Signal(Player, "Visit", Name)
					if not Data.Areas[Name] then
						Data.Areas[Name] = os.time()
						UIService.Notify(Player, "Area", {Name = Name, Description = Part:GetAttribute("Description") or ""})
						ProgressionService.Sync(Player)
					end
				end
			end
		end
	end
end

function WorldService.Credit(Victim, Player)
	if Victim:GetAttribute("Credited") then return end
	if not Player then
		local Hit = LastHit[Victim]
		if not Hit or os.clock() - Hit.Time > DEFEAT_CREDIT_SECONDS or Hit.Player.Parent ~= Players then return end
		Player = Hit.Player
	end
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	Victim:SetAttribute("Credited", true)

	local Level = tonumber(Victim:GetAttribute("Level")) or 1
	local Exp = tonumber(Victim:GetAttribute("ExpReward")) or 25 * Level
	local Money = tonumber(Victim:GetAttribute("MoneyReward")) or 0
	if Exp > 0 then ProgressionService.GrantExp(Player, Exp, "Defeat") end
	if Money > 0 then ProgressionService.GrantMoney(Player, Money) end
	ProgressionService.AddTraining(Player, "Defeat", 1)

	local Entry = Victim:GetAttribute("CodexEntry")
	if type(Entry) == "string" and Entry ~= "" and not Data.Codex[Entry] then
		Data.Codex[Entry] = os.time()
		-- the minimal CODEX ENTRY card (PopupUI; 2026-10-18 UI pass)
		UIService.Notify(Player, "Codex", {Name = Entry, Description = "Added to your Journal (J)."})
		ProgressionService.Sync(Player)
	end
	QuestService.Signal(Player, "Defeat", Victim:GetAttribute("QuestTarget") or Victim:GetAttribute("DisplayName") or Victim.Name)
end

local function Watch(Model)
	if Watched[Model] or not Model:IsA("Model") or Players:GetPlayerFromCharacter(Model) then return end
	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	Watched[Model] = true
	-- Keep NPC physics on the server and never let a hit trip it into FallingDown/Ragdoll.
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	local Root = Model:FindFirstChild("HumanoidRootPart")
	if Root and not Root.Anchored then pcall(Root.SetNetworkOwner, Root, nil) end
	Humanoid.Died:Once(function()
		WorldService.Credit(Model)
	end)
end

-- Combat lock (controls doc): while in combat, menus and Interact are disabled. The server owns
-- the state and mirrors it as the character attribute InCombat for the client UI.
local CombatUntil = setmetatable({}, {__mode = "k"}) -- [Character] = os.clock() deadline

-- the name the combat log shows for whoever is on the other side of the fight
-- Combat log (CombatLogUI): CombatUntil = server time the lock ends, CombatBy = who last hit you,
-- CombatVs = who you last hit (shown when nobody has hit you yet).
local function MarkCombat(Model, Other, WasHit)
	if Model and Players:GetPlayerFromCharacter(Model) then
		CombatUntil[Model] = os.clock() + COMBAT_SECONDS
		Model:SetAttribute("CombatUntil", workspace:GetServerTimeNow() + COMBAT_SECONDS)
		if Other and Other ~= Model then
			-- another player shows as this player knows them (Player Identities: "Subject 03" until identified),
			-- never their Roblox name
			local Viewer, OtherPlayer = Players:GetPlayerFromCharacter(Model), Players:GetPlayerFromCharacter(Other)
			local function NameOf(M)
				if OtherPlayer and M == Other then
					local Ok, Label = pcall(function() return require(ServerScriptService.IdentityService).LabelFor(Viewer, OtherPlayer) end)
					return Ok and Label or "Unknown subject"
				end
				return (M:GetAttribute("DisplayName") or M.Name)
			end
			if WasHit then
				Model:SetAttribute("CombatBy", NameOf(Other))
				Model:SetAttribute("CombatHitAt", workspace:GetServerTimeNow())
			else
				Model:SetAttribute("CombatVs", NameOf(Other))
			end
		end
		if not Model:GetAttribute("InCombat") then Model:SetAttribute("InCombat", true) end
	end
end

function WorldService.InCombat(Player)
	local Character = Player.Character
	return Character ~= nil and (CombatUntil[Character] or 0) > os.clock()
end

function WorldService.Start()
	table.insert(ProgressionService.HitListeners, function(Attacker, Victim, Result)
		MarkCombat(Attacker, Victim, false)
		MarkCombat(Victim, Attacker, true)
		-- Being attacked drops you straight into Combat Mode so you can fight back.
		if Players:GetPlayerFromCharacter(Victim) and Attacker ~= Victim then
			Victim:SetAttribute("CombatMode", true)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local Now = os.clock()
			for Character, Deadline in pairs(CombatUntil) do
				if Deadline <= Now then
					CombatUntil[Character] = nil
					if Character.Parent then
						Character:SetAttribute("InCombat", false)
						Character:SetAttribute("CombatBy", nil)
						Character:SetAttribute("CombatVs", nil)
					end
				end
			end
		end
	end)
	table.insert(ProgressionService.HitListeners, function(Attacker, Victim, Result)
		local Player = Players:GetPlayerFromCharacter(Attacker)
		if Player and Result == "Hit" and not Players:GetPlayerFromCharacter(Victim) then
			LastHit[Victim] = {Player = Player, Time = os.clock()}
			Watch(Victim)
		end
	end)
	local Live = workspace:WaitForChild("World"):WaitForChild("Live")
	for _, Model in ipairs(Live:GetChildren()) do Watch(Model) end
	Live.ChildAdded:Connect(function(Model)
		task.defer(Watch, Model)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			CheckAreas()
		end
	end)
end

return WorldService

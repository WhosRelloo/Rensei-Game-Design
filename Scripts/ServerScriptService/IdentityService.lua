-- IdentityService (2026-10-18): Player Identities, the only writer of profile Identities (Rensei.Identities).
-- Every record comes from a server-seen event; the client never says what it saw.
--   Encounter: a hit between two players (ProgressionService.HitListeners) creates / refreshes each one's
--     record of the other. The one who was hit sees the weapon used on them; both see the other's dress.
--   Witness: a player's alchemy cast (AlchemyService.Cast) is seen by other players within WitnessRange
--     with a clear line of sight: they note the technique.
--   Introduce: a ProximityPrompt on every character ("Introduce yourself", out of Combat Mode only). The
--     player who uses it tells THAT player their name: consent is the act itself.
--   Identify: Requests.Investigation("Identify", Key, Name) names a Suspected subject. It's checked against
--     the subject's live character (they must be in this server); a wrong name locks the record for a while.
--   Evidence links (StoryService.GiveEvidence): evidence with a Technique field links, as a hypothesis, to
--     records where that technique was observed. Never proof, and never an accusation.
-- Records are keyed by the subject's random Identity.CharacterId (filled here on first load). Nothing about
-- the Roblox account is stored or shown, and nothing gives live locations: only where past encounters were.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Rules = require(ReplicatedStorage.Modules.Data.Rensei.Identities)
local EvidenceDefs = require(ReplicatedStorage.Modules.Data.Rensei.Evidence)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local IdentityService = {}

-- how a weapon reads in a record (the item the subject held); anything else uses the item name
local WeaponWords = {
	Katana = "a katana", Rapier = "a rapier", Caestus = "caestus gauntlets", Greatsword = "a greatsword",
	Daggers = "twin daggers", Revolver = "a revolver", Renetti = "a Renetti pistol", Sykov = "a Sykov pistol",
	["Forge Tac"] = "a Forge Tac pistol",
}

local function Data(Player) return ProgressionService.GetData(Player) end

-- the subject's id, filled the first time a character is seen in this place
function IdentityService.CharacterIdOf(Player)
	local D = Data(Player)
	local Identity = D and D.Identity
	if type(Identity) ~= "table" or not Identity.CharacterCreated then return nil end
	if type(Identity.CharacterId) ~= "string" or Identity.CharacterId == "" then
		Identity.CharacterId = HttpService:GenerateGUID(false)
	end
	return Identity.CharacterId
end

local function Book(Player)
	local D = Data(Player)
	if not D then return nil end
	if type(D.Identities) ~= "table" then D.Identities = {Next = 1, Records = {}} end
	D.Identities.Records = D.Identities.Records or {}
	D.Identities.Next = D.Identities.Next or 1
	return D.Identities, D
end

-- profile sync, at most every 1.5 s per player (fights produce many hits)
local Pending = {}
local function Dirty(Player)
	if Pending[Player] then return end
	Pending[Player] = true
	task.delay(1.5, function()
		Pending[Player] = nil
		if Player.Parent then ProgressionService.Sync(Player) end
	end)
end

local function Evict(B)
	local Oldest, OldestKey, OldestNamed, OldestNamedKey
	for Key, R in pairs(B.Records) do
		if (R.Name or "") == "" then
			if not Oldest or (R.Last or 0) < Oldest then Oldest, OldestKey = R.Last or 0, Key end
		elseif not OldestNamed or (R.Last or 0) < OldestNamed then
			OldestNamed, OldestNamedKey = R.Last or 0, Key
		end
	end
	local Key = OldestKey or OldestNamedKey
	if Key then B.Records[Key] = nil end
end

-- the investigator's record of the subject (created when Create is set)
local function Record(Investigator, Subject, Create)
	if Investigator == Subject then return nil end
	local Key = IdentityService.CharacterIdOf(Subject)
	local B = Book(Investigator)
	if not Key or not B or not IdentityService.CharacterIdOf(Investigator) then return nil end
	local R = B.Records[Key]
	if not R and Create then
		if Rules.Count(B.Records) >= Rules.MaxRecords then Evict(B) end
		local Now = os.time()
		R = {N = B.Next, First = Now, Last = Now, Seen = 0, Obs = {}, Name = "", Src = "", Links = {}, Log = {}, Lock = 0}
		B.Next += 1
		B.Records[Key] = R
	end
	return R, Key, B
end

local function AreaName(Character)
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not Root then return nil end
	local Ok, Area = pcall(function() return require(ServerScriptService.WorldService).AreaAt(Root.Position) end)
	return Ok and Area and Area:GetAttribute("AreaName") or nil
end

local function NationOf(Subject)
	local D = Data(Subject)
	local Origin = D and D.Identity and D.Identity.Origin
	if type(Origin) ~= "string" or Origin == "" then return nil end
	local Ok, Customization = pcall(require, ReplicatedStorage.Modules.Data.Rensei.Customization)
	local Nation = Ok and Customization.Nations and Customization.Nations[Origin]
	return Nation and Nation.Name or nil
end

-- held evidence that describes this technique (a hypothesis link, never proof)
local function LinkTechnique(Investigator, R)
	local D = Data(Investigator)
	local Technique = R.Obs and R.Obs.Technique
	if not D or not Technique then return end
	for Id in pairs((D.Story or {}).Evidence or {}) do
		local Def = EvidenceDefs[Id]
		if Def and Def.Technique == Technique and not R.Links[Id] and Rules.Count(R.Links) < Rules.MaxLinks then
			R.Links[Id] = os.time()
		end
	end
end

function IdentityService.Observe(Investigator, Subject, Kind, Value)
	if not Rules.Kinds[Kind] or type(Value) ~= "string" or Value == "" then return end
	local R = Record(Investigator, Subject, true)
	if not R then return end
	if R.Obs[Kind] ~= Value then
		R.Obs[Kind] = Value
		if Kind == "Technique" then LinkTechnique(Investigator, R) end
		Dirty(Investigator)
	end
end

-- a meeting worth writing down (Kind: "Fought" | "Witnessed" | "Met")
function IdentityService.Encounter(Investigator, Subject, Kind)
	local R = Record(Investigator, Subject, true)
	if not R then return end
	local Now = os.time()
	R.Last = Now
	if R.Seen == 0 or Now - (R.Met or 0) >= Rules.EncounterGap then
		R.Seen += 1
		R.Met = Now
		table.insert(R.Log, 1, {At = Now, Kind = Kind, Area = AreaName(Subject.Character)})
		while #R.Log > Rules.MaxLog do table.remove(R.Log) end
		Dirty(Investigator)
	end
	local Nation = NationOf(Subject)
	if Nation then IdentityService.Observe(Investigator, Subject, "Dress", Nation) end
end

-- a hit between two players: both meet; the one hit sees the weapon used on them
local function OnHit(Attacker, Victim)
	local A, V = Players:GetPlayerFromCharacter(Attacker), Players:GetPlayerFromCharacter(Victim)
	if not A or not V or A == V then return end
	IdentityService.Encounter(V, A, "Fought")
	IdentityService.Encounter(A, V, "Fought")
	local Item = Attacker:GetAttribute("WeaponItem")
	IdentityService.Observe(V, A, "Weapon", Item and (WeaponWords[Item] or Item) or "bare fists")
end

-- AlchemyService.Cast: everyone who can see the caster notes the technique
local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude
function IdentityService.Witness(Caster, Affinity)
	local C = Caster.Character
	local Head = C and C:FindFirstChild("Head")
	if not Head or type(Affinity) ~= "string" then return end
	for _, Other in ipairs(Players:GetPlayers()) do
		local OC = Other ~= Caster and Other.Character
		local Eye = OC and OC:FindFirstChild("Head")
		if Eye and (Eye.Position - Head.Position).Magnitude <= Rules.WitnessRange then
			Rays.FilterDescendantsInstances = {C, OC}
			if not workspace:Raycast(Eye.Position, Head.Position - Eye.Position, Rays) then
				IdentityService.Encounter(Other, Caster, "Witnessed")
				IdentityService.Observe(Other, Caster, "Technique", Affinity)
			end
		end
	end
end

-- StoryService.GiveEvidence: a new evidence item may describe a technique already observed
function IdentityService.OnEvidence(Player, EvidenceId)
	local Def = EvidenceDefs[EvidenceId]
	local B = Def and Def.Technique and Book(Player)
	if not B then return end
	for _, R in pairs(B.Records) do
		if R.Obs and R.Obs.Technique == Def.Technique and not R.Links[EvidenceId] and Rules.Count(R.Links) < Rules.MaxLinks then
			R.Links[EvidenceId] = os.time()
		end
	end
	Dirty(Player)
end

local function Confirm(Investigator, Subject, R, Source)
	local D = Data(Subject)
	local Name = D and D.Identity and D.Identity.Name
	if type(Name) ~= "string" or Name == "" then return false end
	R.Name = Name
	R.Src = Source
	R.Standing = Subject:GetAttribute("Title") or nil -- the public rank title (shown on the leaderboard)
	R.Lock = 0
	UIService.Notify(Investigator, "Banner", {Text = "Identified - [" .. Name .. "]"})
	Dirty(Investigator)
	return true
end

-- Subject introduces themselves to Listener (the prompt on Listener's character, used by Subject)
local LastIntro = {} -- ["<subject>:<listener>"] = os.clock()
function IdentityService.Introduce(Subject, Listener)
	if Subject == Listener then return end
	local SC, LC = Subject.Character, Listener.Character
	local SR, LR = SC and SC:FindFirstChild("HumanoidRootPart"), LC and LC:FindFirstChild("HumanoidRootPart")
	if not SR or not LR or (SR.Position - LR.Position).Magnitude > Rules.IntroduceRange + 2 then return end
	local Pair = Subject.UserId .. ":" .. Listener.UserId
	if os.clock() - (LastIntro[Pair] or -999) < 30 then return end
	LastIntro[Pair] = os.clock()
	IdentityService.Encounter(Listener, Subject, "Met")
	IdentityService.Encounter(Subject, Listener, "Met")
	local R = Record(Listener, Subject, true)
	if not R then return end
	local Already = (R.Name or "") ~= ""
	if Confirm(Listener, Subject, R, "Introduced") then
		UIService.Notify(Subject, "Toast", {Text = Already and "They already know your name." or "You introduced yourself."})
	end
end

-- Requests.Investigation("Identify", Key, Name): returns ok, text
function IdentityService.Identify(Investigator, Key, Name)
	local B = Book(Investigator)
	local R = B and type(Key) == "string" and B.Records[Key]
	if not R then return false, "There's no such record." end
	if (R.Name or "") ~= "" then return true, "You already know who they are." end
	if not Rules.CanName(R) then return false, "You don't have enough to go on yet." end
	if os.time() < (R.Lock or 0) then return false, "You named them wrong recently. Watch them a while longer." end
	if type(Name) ~= "string" or #Name == 0 or #Name > 40 then return false, "Pick a name." end
	local Subject
	for _, P in ipairs(Players:GetPlayers()) do
		if P ~= Investigator and IdentityService.CharacterIdOf(P) == Key then Subject = P break end
	end
	if not Subject then return false, "They have to be about to confirm a name. Try when you next see them." end
	local D = Data(Subject)
	if not D or D.Identity.Name ~= Name then
		R.Lock = os.time() + Rules.WrongLock
		Dirty(Investigator)
		return false, "That name doesn't fit what you've seen. The record is locked for a while."
	end
	Confirm(Investigator, Subject, R, "Named")
	return true, "Confirmed: " .. Name .. "."
end

-- the combat log's name for Subject, as Viewer knows them (WorldService)
function IdentityService.LabelFor(Viewer, Subject)
	local B = Book(Viewer)
	local Key = IdentityService.CharacterIdOf(Subject)
	local R = B and Key and B.Records[Key]
	return R and Rules.Label(R) or "Unknown subject"
end

-- the Introduce prompt on each character (enabled only while that character is out of Combat Mode)
local function AddPrompt(Player, Character)
	local Root = Character:WaitForChild("HumanoidRootPart", 10)
	if not Root or Root:FindFirstChild("IntroducePrompt") then return end
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "IntroducePrompt"
	Prompt.ActionText = "Introduce yourself"
	Prompt.ObjectText = ""
	Prompt.HoldDuration = 0.6
	Prompt.MaxActivationDistance = Rules.IntroduceRange
	Prompt.RequiresLineOfSight = true
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI; the owner's own is hidden (JournalUI)
	Prompt.Parent = Root
	local function Update() Prompt.Enabled = Character:GetAttribute("CombatMode") ~= true end
	Update()
	Character:GetAttributeChangedSignal("CombatMode"):Connect(Update)
	Prompt.Triggered:Connect(function(User)
		if User ~= Player then IdentityService.Introduce(User, Player) end
	end)
end

function IdentityService.Start()
	table.insert(ProgressionService.HitListeners, function(Attacker, Victim)
		pcall(OnHit, Attacker, Victim)
	end)
	local function Added(Player)
		Player.CharacterAdded:Connect(function(Character)
			task.spawn(AddPrompt, Player, Character)
			-- fill the CharacterId once the profile has loaded
			task.delay(3, function() IdentityService.CharacterIdOf(Player) end)
		end)
		if Player.Character then task.spawn(AddPrompt, Player, Player.Character) end
	end
	Players.PlayerAdded:Connect(Added)
	for _, P in ipairs(Players:GetPlayers()) do Added(P) end
	Players.PlayerRemoving:Connect(function(Player)
		Pending[Player] = nil
		for Pair in pairs(LastIntro) do
			if Pair:find(Player.UserId, 1, true) then LastIntro[Pair] = nil end
		end
	end)
end

return IdentityService

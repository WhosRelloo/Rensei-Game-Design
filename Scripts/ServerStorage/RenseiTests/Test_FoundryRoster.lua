-- Test_FoundryRoster (Foundry data plan Task 5, 2026-10-25): Foundry Yard's roster (Townsfolk.Regions.Foundry), 26
-- townsfolk on two shifts. Run in the Play VM (LMRunSuite) in Foundry: it reads Foundry's posts
-- (workspace.World.Map.Foundry) and the data modules this task changes.
--   * Validate: TownsfolkLogic.Validate passes against the RenseiPosts in Map.Foundry (every hour covered, one
--     townsperson per post at a time, every post exists).
--   * Size: 26 entries, ids unique and starting "fy_".
--   * Names (Ruling 3): no full Name is a Lindenmoor name or a newcomer name, and no WORD of a first name (everything
--     before the surname: a two-word given name is checked word by word, fix round 1 Ruling 28) is a word of a Dialogues
--     Speaker, an enemy DisplayName, the DisplayName of a dialogue NPC in workspace, a Lindenmoor name or a newcomer
--     name. NamesControl: the same function reports "Wren Test" (Wren the automail mechanic), a taken word in either
--     word of a two-word first name ("Wren Ash Test", "Ash Wren Test"), and one fake per source, each traced to its
--     source: Harlan (a Speaker), Dask (an enemy), Garrick (Lindenmoor), Greta (a newcomer), and a test NPC put in
--     workspace with a DialogueId for the run.
--   * Nations: every Look.Nation is in Customization.NationLooks; every Idle is an animation under
--     ReplicatedStorage.Assets.Animations.
--   * Shelters: a Shelter post in Map.Foundry within 145 studs (PROPOSAL margin under TownsfolkService.ShelterRadius
--     150, Ruling 37) of every post a schedule uses.
--   * Hours: at each hour the posts in use are distinct; the canteen seats hold at least 4 at 13:00, 14:00 and 22:00
--     (shift change); every market_trader_N is in use at 08:00 and 19:00 and at no hour from 20:00 to 07:00.
local CollectionService = game:GetService("CollectionService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local TownsfolkLogic = require(Rensei.TownsfolkLogic)
local Customization = require(Rensei.Customization)

local SHELTER_MAX = 145 -- PROPOSAL (global constraints: under ShelterRadius 150)
local SIZE = 26
local CANTEEN_MIN = 4 -- PROPOSAL: the canteen fills at shift change
local MARKET = {"market_trader_1", "market_trader_2", "market_trader_3", "market_trader_4"}

local function Roster(T)
	local R = require(Rensei.Townsfolk).Regions.Foundry
	T.True(type(R) == "table" and #R > 0, "Townsfolk.Regions.Foundry has a roster")
	return R
end

-- the RenseiPosts in Map.Foundry: {[PostId] = Part}
local function Posts(T)
	local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
		and workspace.World.Map:FindFirstChild("Foundry")
	T.True(Map ~= nil, "workspace.World.Map.Foundry exists (run this in Foundry)")
	local Out = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(Map) then Out[P:GetAttribute("PostId")] = P end
	end
	return Out
end

-- every word of Text into Into: [lower-case word] = 'Source "Text"' (where the name was found)
local function Words(Text, Source, Into)
	for W in string.gmatch(tostring(Text), "[%a']+") do Into[string.lower(W)] = Source .. " \"" .. tostring(Text) .. "\"" end
end

-- the first name: everything before the surname ("Mei Lin Hu" -> "Mei Lin"); a one-word name is its own first name
local function FirstName(Name)
	return string.match(Name, "^(.-)%s+%S+$") or Name
end

-- every name already in the game: Full ([full name] = where) and Taken ([lower-case word] = source and name)
local function TakenNames()
	local Full, Taken = {}, {}
	-- every Speaker anywhere in Rensei.Dialogues (a recursive walk: trainers, style trainers, Wren, nested tables)
	local Seen = {}
	local function Walk(V)
		if type(V) ~= "table" or Seen[V] then return end
		Seen[V] = true
		for K, X in pairs(V) do
			if K == "Speaker" and type(X) == "string" then Words(X, "Dialogues Speaker", Taken) end
			Walk(X)
		end
	end
	Walk(require(Rensei.Dialogues))
	for _, E in pairs(require(Rensei.TuningConfig).Enemies or {}) do
		if type(E) == "table" and type(E.DisplayName) == "string" then Words(E.DisplayName, "TuningConfig enemy", Taken) end
	end
	for _, I in ipairs(workspace:GetDescendants()) do
		if I:GetAttribute("DialogueId") ~= nil and type(I:GetAttribute("DisplayName")) == "string" then
			Words(I:GetAttribute("DisplayName"), "workspace NPC", Taken)
		end
	end
	for _, D in ipairs(require(Rensei.Townsfolk).Regions.Lindenmoor or {}) do
		Full[D.Name] = "Lindenmoor"
		Words(D.Name, "Lindenmoor", Taken)
	end
	for Nation, List in pairs(TownsfolkLogic.NewcomerNames) do
		for _, N in ipairs(List) do
			Full[N] = "NewcomerNames." .. Nation
			Words(N, "NewcomerNames." .. Nation, Taken)
		end
	end
	return Full, Taken
end

-- the entries whose name is already the game's: {"<Id>: <why>", ...}
local function NameClashes(Entries)
	local Full, Taken = TakenNames()
	local Out = {}
	for _, D in ipairs(Entries) do
		local Name = tostring(D.Name)
		if Full[Name] then table.insert(Out, D.Id .. ": " .. Name .. " is in " .. Full[Name]) end
		local First = FirstName(Name)
		for W in string.gmatch(First, "[%a']+") do
			local Why = Taken[string.lower(W)]
			if Why then table.insert(Out, D.Id .. ": first name " .. First .. " has " .. W .. ", from " .. Why) end
		end
	end
	return Out
end

local function UsedAt(R, Hour)
	local Out = {}
	for _, D in ipairs(R) do table.insert(Out, {Id = D.Id, Post = TownsfolkLogic.PostAt(D.Schedule, Hour)}) end
	return Out
end

return {
	Validate = function(T)
		local R = Roster(T)
		local PostIds = {}
		for Id in pairs(Posts(T)) do PostIds[Id] = true end
		local Ok, Errs = TownsfolkLogic.Validate(R, PostIds)
		T.True(Ok, "Foundry's roster validates: " .. table.concat(Errs, " | "))
	end,

	Size = function(T)
		local R = Roster(T)
		T.Eq(#R, SIZE, "townsfolk in Foundry's roster")
		local Seen, Bad = {}, {}
		for I, D in ipairs(R) do
			if type(D.Id) ~= "string" or string.sub(D.Id, 1, 3) ~= "fy_" then table.insert(Bad, "entry " .. I .. " id " .. tostring(D.Id)) end
			if Seen[D.Id] then table.insert(Bad, "duplicate " .. tostring(D.Id)) end
			Seen[D.Id] = true
		end
		T.Eq(#Bad, 0, "ids unique and starting fy_; not: " .. table.concat(Bad, ", "))
	end,

	Names = function(T)
		local Clashes = NameClashes(Roster(T))
		T.Eq(#Clashes, 0, "names already in the game: " .. table.concat(Clashes, "; "))
	end,

	NamesControl = function(T)
		-- a dialogue NPC put in workspace for this run (removed after), to prove that source is read
		local Npc = Instance.new("Model")
		Npc.Name = "T5_NamesControlNpc"
		Npc:SetAttribute("DialogueId", "t5_names_control")
		Npc:SetAttribute("DisplayName", "Quorvane the Tester")
		Npc.Parent = workspace
		local Ok, Clashes = pcall(NameClashes, {
			{Id = "fake_wren", Name = "Wren Test"},
			{Id = "fake_wren_ash", Name = "Wren Ash Test"},
			{Id = "fake_ash_wren", Name = "Ash Wren Test"},
			{Id = "fake_speaker", Name = "Harlan Test"},
			{Id = "fake_enemy", Name = "Dask Test"},
			{Id = "fake_npc", Name = "Quorvane Test"},
			{Id = "fake_lindenmoor", Name = "Garrick Test"},
			{Id = "fake_newcomer", Name = "Greta Test"},
			{Id = "fake_newcomer_full", Name = "Hal Brenner"},
		})
		Npc:Destroy()
		T.True(Ok, "NameClashes ran: " .. tostring(Clashes))
		local Joined = table.concat(Clashes, "; ")
		for _, Want in ipairs({
			"fake_wren: first name Wren has Wren, from Dialogues Speaker \"Wren\"",
			"fake_wren_ash: first name Wren Ash has Wren, from Dialogues Speaker",
			"fake_ash_wren: first name Ash Wren has Wren, from Dialogues Speaker",
			"fake_speaker: first name Harlan has Harlan, from Dialogues Speaker \"Coach Harlan\"",
			"fake_enemy: first name Dask has Dask, from TuningConfig enemy",
			"fake_npc: first name Quorvane has Quorvane, from workspace NPC \"Quorvane the Tester\"",
			"fake_lindenmoor: first name Garrick has Garrick, from Lindenmoor \"Garrick Ashby\"",
			"fake_newcomer: first name Greta has Greta, from NewcomerNames.Amestrian \"Greta Vossler\"",
			"fake_newcomer_full: Hal Brenner is in NewcomerNames",
		}) do
			T.True(string.find(Joined, Want, 1, true) ~= nil, "the Names check reports '" .. Want .. "'; got: " .. Joined)
		end
	end,

	Nations = function(T)
		local R = Roster(T)
		local Anims = game.ReplicatedStorage:FindFirstChild("Assets") and game.ReplicatedStorage.Assets:FindFirstChild("Animations")
		T.True(Anims ~= nil, "ReplicatedStorage.Assets.Animations exists")
		local Bad = {}
		for _, D in ipairs(R) do
			local Nation = type(D.Look) == "table" and D.Look.Nation or nil
			if not Customization.NationLooks[Nation] then table.insert(Bad, D.Id .. " nation " .. tostring(Nation)) end
			if type(D.Idle) ~= "string" or not Anims:FindFirstChild(D.Idle, true) then table.insert(Bad, D.Id .. " idle " .. tostring(D.Idle)) end
		end
		T.Eq(#Bad, 0, "nations in NationLooks and idles in Assets.Animations; not: " .. table.concat(Bad, ", "))
	end,

	Shelters = function(T)
		local R = Roster(T)
		local P = Posts(T)
		local Shelters = {}
		for _, Part in pairs(P) do
			if Part:GetAttribute("Kind") == "Shelter" then table.insert(Shelters, Part) end
		end
		T.True(#Shelters > 0, "Map.Foundry has Shelter posts")
		local Far, Done = {}, {}
		for _, D in ipairs(R) do
			for _, S in ipairs(D.Schedule) do
				local Post = P[S[3]]
				if Done[S[3]] then continue end
				Done[S[3]] = true
				if not Post then table.insert(Far, tostring(S[3]) .. ": no such post") continue end
				local At = (Post.CFrame * CFrame.new(0, 3, 0)).Position -- (where the rig's root stands)
				local Best = math.huge
				for _, Sh in ipairs(Shelters) do Best = math.min(Best, (Sh.Position - At).Magnitude) end
				if Best > SHELTER_MAX then table.insert(Far, ("%s: %.1f"):format(S[3], Best)) end
			end
		end
		T.Eq(#Far, 0, "a shelter within " .. SHELTER_MAX .. " of every post used; not: " .. table.concat(Far, ", "))
	end,

	Hours = function(T)
		local R = Roster(T)
		local Clash = {}
		for H = 0, 23 do
			local By = {}
			for _, U in ipairs(UsedAt(R, H)) do
				if By[U.Post] then table.insert(Clash, ("%02d:00 %s (%s, %s)"):format(H, tostring(U.Post), By[U.Post], U.Id)) end
				By[U.Post] = U.Id
			end
		end
		T.Eq(#Clash, 0, "one townsperson per post each hour; not: " .. table.concat(Clash, ", "))
		for _, H in ipairs({13, 14, 22}) do
			local N = 0
			for _, U in ipairs(UsedAt(R, H)) do
				if string.match(tostring(U.Post), "^canteen_seat_%d+$") then N += 1 end
			end
			T.True(N >= CANTEEN_MIN, ("the canteen seats hold %d at %02d:00 (want at least %d)"):format(N, H, CANTEEN_MIN))
		end
		local Open = {[8] = true, [19] = true}
		local Shut = {}
		for H = 20, 23 do Shut[H] = true end
		for H = 0, 7 do Shut[H] = true end
		local Bad = {}
		for _, Stall in ipairs(MARKET) do
			for H = 0, 23 do
				local Used = false
				for _, U in ipairs(UsedAt(R, H)) do
					if U.Post == Stall then Used = true end
				end
				if Open[H] and not Used then table.insert(Bad, ("%s empty at %02d:00"):format(Stall, H)) end
				if Shut[H] and Used then table.insert(Bad, ("%s in use at %02d:00"):format(Stall, H)) end
			end
		end
		T.Eq(#Bad, 0, "the market is kept 08-20; not: " .. table.concat(Bad, ", "))
	end,
}

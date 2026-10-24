-- Play_LindenmoorData (Lindenmoor import Task 8, 2026-10-24): the expansion's game data in Ye, inside the game VM
-- (LMRunSuite) with the Play client connected, inside the snapshot / restore runner.
--   * AreaLookup: WorldService.AreaAt at the centre of each of the ten expansion areas returns that area; at a relocated
--     trial site (the Burned Laboratory, now inside Bramble Woods) the site's own smaller box wins; and the smallest box
--     wins whatever order the boxes are found in (two nested pairs made far above the map, tagged in both orders).
--   * ClueQuests: inspecting each expansion clue (the InvestigationService handler, as the prompt does) gives its
--     evidence and starts its quest with the Evidence objective caught up; the townsperson named in the roster's Clue
--     then says the clue line, which finishes the quest. Quest rewards are switched off while the test runs.
--   * TownsfolkRoster: Lindenmoor's roster passes TownsfolkLogic.Validate against the posts in the place, uses every
--     post, dresses everyone as Amestrian, was spawned at Start (no refusal), and, with the clock held at 10:00,
--     LoadRegion stands every townsperson at its 10:00 post.
-- Everything the tests change (test parts, the clock hold, the player's position, quest / evidence state, patched
-- rewards and the talk cooldown) is put back.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei

local AREAS = {"Outlying Farmsteads", "Mine Approach", "Mill Creek Gorge", "East Lookout", "Bramble Woods",
	"Training Field", "Ridge Marker", "North Meadows", "Cypress Ridge Rim", "Northeast Gap"}
local CLUES = {
	{Clue = "lm_ridge_marker", Evidence = "lm_ridge_survey", Quest = "lm_ridge"},
	{Clue = "lm_mine_shaft", Evidence = "lm_shaft_ore", Quest = "lm_mine"},
}

local function AreaParts()
	local Out = {} -- [AreaName] = {Part, ...} (workspace only)
	for _, P in ipairs(CollectionService:GetTagged("RenseiArea")) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) then
			local Name = P:GetAttribute("AreaName") or P.Name
			Out[Name] = Out[Name] or {}
			table.insert(Out[Name], P)
		end
	end
	return Out
end

local function NameAt(Pos)
	local Part = require(SSS.WorldService).AreaAt(Pos)
	return Part and (Part:GetAttribute("AreaName") or Part.Name) or nil
end

local function Inside(Part, Pos)
	local L = Part.CFrame:PointToObjectSpace(Pos)
	local H = Part.Size / 2
	return math.abs(L.X) <= H.X and math.abs(L.Y) <= H.Y and math.abs(L.Z) <= H.Z
end

local function Box(Name, CF, Size)
	local P = Instance.new("Part")
	P.Name = "TestArea_" .. Name
	P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
	P.Transparency = 1
	P.Size = Size
	P.CFrame = CF
	P:SetAttribute("AreaName", Name)
	P.Parent = workspace
	CollectionService:AddTag(P, "RenseiArea")
	return P
end

-- runs Body with the player's character held still near Pos; puts it back afterwards
local function Near(Player, Pos, Body)
	local C = Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	assert(Root, "the player has a character")
	local Home, WasAnchored = C:GetPivot(), Root.Anchored
	local Ok, Err = pcall(function()
		Root.Anchored = true
		C:PivotTo(CFrame.new(Pos + Vector3.new(0, 3, 5)))
		task.wait(0.1)
		Body()
	end)
	pcall(function()
		C:PivotTo(Home)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.Anchored = WasAnchored
	end)
	if not Ok then error(Err, 0) end
end

return {
	AreaLookup = function(T)
		local Parts = AreaParts()
		for _, Name in ipairs(AREAS) do
			local List = Parts[Name]
			T.True(List ~= nil and #List == 1, Name .. ": one box in the place (got " .. (List and #List or 0) .. ")")
			T.True(List[1]:IsDescendantOf(workspace.World.Map.LindenmoorExpansion), Name .. " is the expansion's")
			T.Eq(NameAt(List[1].Position), Name, Name .. " at its centre")
		end
		-- the relocated Burned Laboratory sits inside Bramble Woods: its own, smaller box wins
		local Lab = Parts["Burned Laboratory"] and Parts["Burned Laboratory"][1]
		T.True(Lab ~= nil, "the Burned Laboratory's box is in the place")
		T.True(Inside(Parts["Bramble Woods"][1], Lab.Position), "the lab's centre is inside Bramble Woods (the overlap)")
		T.Eq(NameAt(Lab.Position), "Burned Laboratory", "at the relocated lab")
		-- order doesn't matter: two nested pairs far above the map, the big box tagged first in one, last in the other
		local Made = {}
		local Ok, Err = pcall(function()
			local A = CFrame.new(0, 5000, 0)
			local B = CFrame.new(1000, 5000, 0)
			table.insert(Made, Box("__TestBigA", A, Vector3.new(200, 200, 200)))
			table.insert(Made, Box("__TestSmallA", A, Vector3.new(20, 20, 20)))
			table.insert(Made, Box("__TestSmallB", B, Vector3.new(20, 20, 20)))
			table.insert(Made, Box("__TestBigB", B, Vector3.new(200, 200, 200)))
			T.Eq(NameAt(A.Position), "__TestSmallA", "the smaller box wins (big one tagged first)")
			T.Eq(NameAt(B.Position), "__TestSmallB", "the smaller box wins (big one tagged last)")
			T.Eq(NameAt(A.Position + Vector3.new(50, 0, 0)), "__TestBigA", "outside the small box: the big one")
			T.Eq(NameAt(Vector3.new(500, 5000, 0)), nil, "between them: no area")
		end)
		for _, P in ipairs(Made) do P:Destroy() end
		if not Ok then error(Err, 0) end
	end,

	ClueQuests = function(T)
		local InvestigationService = require(SSS.InvestigationService)
		local DialogueService = require(SSS.DialogueService)
		local TS = require(SSS.TownsfolkService)
		local PS = require(SSS.ProgressionService)
		local Content = require(Rensei.Investigation)
		local EvidenceDefs = require(Rensei.Evidence)
		local Quests = require(Rensei.Quests)
		local Roster = require(Rensei.Townsfolk).Regions.Lindenmoor or {}
		local Player = game.Players:GetPlayers()[1]
		T.True(Player ~= nil, "a player in the game")
		local Data = PS.GetData(Player)
		T.True(type(Data) == "table" and type(Data.Story) == "table" and type(Data.Quests) == "table", "the player's save is loaded")

		local Clues = {}
		for _, P in ipairs(CollectionService:GetTagged("RenseiClue")) do
			if P:IsDescendantOf(workspace) then Clues[P:GetAttribute("ClueId")] = P end
		end
		local OldTracked, OldCooldown = Data.Quests.Tracked, TS.TalkCooldown
		local Saved = {}
		for _, C in ipairs(CLUES) do
			Saved[C.Quest] = {Rewards = Quests[C.Quest] and Quests[C.Quest].Rewards, Ev = Data.Story.Evidence[C.Evidence],
				Active = Data.Quests.Active[C.Quest], Done = Data.Quests.Completed[C.Quest]}
		end
		local Ok, Err = pcall(function()
			TS.TalkCooldown = 0
			for _, C in ipairs(CLUES) do
				local Def, Quest = Content.Inspects[C.Clue], Quests[C.Quest]
				T.True(Def ~= nil, C.Clue .. " has an inspect def")
				T.Eq(Def.Evidence, C.Evidence, C.Clue .. "'s evidence")
				T.Eq(Def.StartsQuest, C.Quest, C.Clue .. " starts " .. C.Quest)
				T.True(EvidenceDefs[C.Evidence] ~= nil, C.Evidence .. " has an evidence def")
				T.True(Quest ~= nil and #Quest.Stages == 1, C.Quest .. " is a one-stage quest")
				local EvObj, SigObj
				for _, O in ipairs(Quest.Stages[1].Objectives) do
					if O.Kind == "Evidence" and O.Target == C.Evidence then EvObj = O end
					if O.Kind == "Signal" then SigObj = O end
				end
				T.True(EvObj ~= nil, C.Quest .. " has the Evidence objective")
				T.True(SigObj ~= nil, C.Quest .. " has the townsperson's Signal objective")
				local Teller
				for _, D in ipairs(Roster) do
					if type(D.Clue) == "table" and D.Clue.Quest == C.Quest then Teller = D end
				end
				T.True(Teller ~= nil, "a Lindenmoor townsperson has the clue line for " .. C.Quest)
				T.Eq(Teller.Clue.Signal, SigObj.Target, C.Quest .. ": the clue line signals the objective")

				local Part = Clues[C.Clue]
				T.True(Part ~= nil, C.Clue .. " is in the place")
				T.True(Part:FindFirstChild("InspectPrompt") ~= nil, C.Clue .. " got its Inspect prompt at Start")
				T.Eq(Part:GetAttribute("InspectId"), C.Clue, C.Clue .. ": InspectId = ClueId")

				Quest.Rewards = nil -- (no real rewards from a test)
				Data.Story.Evidence[C.Evidence] = nil
				Data.Quests.Active[C.Quest] = nil
				Data.Quests.Completed[C.Quest] = nil
				Near(Player, Part.Position, function()
					T.True(InvestigationService.Inspect(Player, C.Clue, Part), C.Clue .. " was inspected")
				end)
				T.True(Data.Story.Evidence[C.Evidence] ~= nil, C.Clue .. " gave " .. C.Evidence)
				local State = Data.Quests.Active[C.Quest]
				T.True(State ~= nil, C.Clue .. " started " .. C.Quest)
				T.Eq(State.Stage, 1, C.Quest .. " on its one stage")
				T.Eq(State.Progress[EvObj.Id], 1, C.Quest .. ": the Evidence objective is caught up")
				T.Eq(State.Progress[SigObj.Id], 0, C.Quest .. ": not told yet")

				-- the townsperson's clue line finishes it
				T.True(TS.Get(Teller.Id) ~= nil, Teller.Id .. " is spawned")
				local Text, Kind = TS.Talk(Player, Teller.Id)
				T.Eq(Kind, "Clue", Teller.Id .. " says the clue line")
				T.Eq(Text, Teller.Clue.Text)
				T.True(Data.Quests.Active[C.Quest] == nil and Data.Quests.Completed[C.Quest] ~= nil, C.Quest .. " is complete")
			end
		end)
		pcall(function() DialogueService.Close(Player) end)
		pcall(function()
			TS.TalkCooldown = OldCooldown
			for _, C in ipairs(CLUES) do
				local S = Saved[C.Quest]
				if Quests[C.Quest] then Quests[C.Quest].Rewards = S.Rewards end
				Data.Story.Evidence[C.Evidence] = S.Ev
				Data.Quests.Active[C.Quest] = S.Active
				Data.Quests.Completed[C.Quest] = S.Done
			end
			Data.Quests.Tracked = OldTracked
			PS.Sync(Player)
		end)
		if not Ok then error(Err, 0) end
	end,

	TownsfolkRoster = function(T)
		local TS = require(SSS.TownsfolkService)
		local WorldClock = require(SSS.WorldClock)
		local TownsfolkLogic = require(Rensei.TownsfolkLogic)
		local Roster = require(Rensei.Townsfolk).Regions.Lindenmoor
		T.True(type(Roster) == "table" and #Roster > 0, "Townsfolk.Regions.Lindenmoor has a roster")
		T.Eq(require(SSS.TravelService).Here(), "Lindenmoor", "Ye loads Lindenmoor's roster")

		local Posts, PostIds = {}, {}
		for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do
			if P:IsDescendantOf(workspace) then
				Posts[P:GetAttribute("PostId")] = P
				PostIds[P:GetAttribute("PostId")] = true
			end
		end
		local Ok, Errs = TownsfolkLogic.Validate(Roster, PostIds)
		T.True(Ok, "the roster validates: " .. table.concat(Errs, " | "))
		-- every post in the place is someone's at some hour
		local Used = {}
		for _, D in ipairs(Roster) do
			T.Eq(D.Look.Nation, "Amestrian", D.Id .. " wears Amestrian clothing")
			for _, S in ipairs(D.Schedule) do Used[S[3]] = true end
		end
		local Unused = {}
		for Id in pairs(PostIds) do if not Used[Id] then table.insert(Unused, Id) end end
		table.sort(Unused)
		T.Eq(#Unused, 0, "posts nobody uses: " .. table.concat(Unused, ", "))
		-- spawned at Start: a refused roster spawns nobody
		for _, D in ipairs(Roster) do T.True(TS.Get(D.Id) ~= nil, D.Id .. " was spawned at Start") end

		local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
		local Run, RunErr = pcall(function()
			WorldClock.Hold(10)
			T.True(TS.LoadRegion("Lindenmoor", Roster), "LoadRegion accepts the roster")
			task.wait(1.5) -- (the service's own 1 Hz Step runs on the same held hour)
			for _, D in ipairs(Roster) do
				local Want = TownsfolkLogic.PostAt(D.Schedule, 10)
				local Rig = TS.Get(D.Id)
				T.True(Rig ~= nil, D.Id .. " is spawned")
				T.Eq(Rig:GetAttribute("PostId"), Want, D.Id .. " is at its 10:00 post")
				T.Eq(Rig:GetAttribute("Nation"), "Amestrian", D.Id .. " is dressed Amestrian")
				local Post = Posts[Want]
				local Stand = (Post.CFrame * CFrame.new(0, 3, 0)).Position
				local Root = Rig:FindFirstChild("HumanoidRootPart")
				local Off = Vector3.new(Root.Position.X - Stand.X, 0, Root.Position.Z - Stand.Z).Magnitude
				T.True(Off <= 1.5, D.Id .. " stands at " .. Want .. " (" .. string.format("%.1f", Off) .. " studs off)")
			end
		end)
		pcall(function()
			if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end
		end)
		if not Run then error(RunErr, 0) end
	end,
}

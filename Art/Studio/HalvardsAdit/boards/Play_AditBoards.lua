-- Halvard's Adit boards (owner request 2026-10-20): the BoardedMouth is a per-player Breakable mechanism
-- (Rensei.Puzzles adit_boards). Three melee strikes break it (a heavy counts 2), any alchemy element breaks it at
-- once, the break is saved (Story.Flags.Mech_adit_boards) and shared with the breaker's party in this server.
-- Runs in the game VM (a Play-mode Script) inside the profile snapshot / restore harness; every test puts the
-- boards back to Whole and clears the saved flag when it ends.
local SSS = game.ServerScriptService
local Players = game:GetService("Players")
local PZ = require(SSS.PuzzleService)
local PG = require(SSS.ProgressionService)
local PartyService = require(SSS.PartyService)
local Player = Players:GetPlayers()[1]
local Boards = workspace.World.Map.HalvardsAdit.Interactables.BoardedMouth
local Pos = Boards.InspectAnchor.Position -- in front of the planks, where a swing lands
local Inward = Vector3.new(1, 0, 0) -- the planks face -X; the adit runs +X
local ID = "adit_boards"

local function Data() return PG.GetData(Player) end
local function Flag() return Data().Story.Flags["Mech_" .. ID] end
local function Fresh()
	PZ.SetState(Player, ID, "Whole", nil, true) -- also resets the strike count
	Data().Story.Flags["Mech_" .. ID] = nil
end
local function Guard(Body)
	Fresh()
	local Ok, Err = pcall(Body)
	Fresh()
	if not Ok then error(Err, 0) end
end

return {
	A_ThreeStrikesBreakAFourthDoesNothing = function(T)
		Guard(function()
			T.True(type(PZ.Strike) == "function", "PuzzleService.Strike exists")
			T.Eq(PZ.StateOf(Player, ID), "Whole", "starts Whole")
			PZ.Strike(Player, Pos, false)
			PZ.Strike(Player, Pos, false)
			T.Eq(PZ.StateOf(Player, ID), "Whole", "two hits: still Whole")
			T.Eq(Flag(), nil, "nothing saved yet")
			PZ.Strike(Player, Pos, false)
			T.Eq(PZ.StateOf(Player, ID), "Broken", "the third hit breaks them")
			T.Eq(Flag(), "Broken", "saved as Story.Flags.Mech_adit_boards")
			local Calls = 0
			local Real = PZ.SetState
			PZ.SetState = function(...) Calls += 1 return Real(...) end
			local Ok, Err = pcall(PZ.Strike, Player, Pos, false)
			PZ.SetState = Real
			T.True(Ok, "a fourth strike doesn't error: " .. tostring(Err))
			T.Eq(Calls, 0, "a fourth strike changes nothing")
			T.Eq(PZ.StateOf(Player, ID), "Broken", "still Broken")
		end)
	end,
	B_HeavyCountsTwo = function(T)
		Guard(function()
			PZ.Strike(Player, Pos, true)
			T.Eq(PZ.StateOf(Player, ID), "Whole", "one heavy: still Whole")
			PZ.Strike(Player, Pos, false)
			T.Eq(PZ.StateOf(Player, ID), "Broken", "heavy (2) + light (1) = 3")
		end)
	end,
	C_StrikesOutOfRangeDoNothing = function(T)
		Guard(function()
			local Far = Pos - Inward * 12
			for _ = 1, 4 do PZ.Strike(Player, Far, true) end
			T.Eq(PZ.StateOf(Player, ID), "Whole", "12 studs off: nothing")
			PZ.Strike(Player, Pos, true)
			T.Eq(PZ.StateOf(Player, ID), "Whole", "the far strikes didn't count")
		end)
	end,
	D_FlameBreaksThemAtOnce = function(T)
		Guard(function()
			PZ.React(Player, "Flame", Pos - Inward * 4, Inward)
			T.Eq(PZ.StateOf(Player, ID), "Broken", "one Flame cast")
			T.Eq(Flag(), "Broken", "saved")
		end)
	end,
	E_EveryElementBreaksThem = function(T)
		for _, Element in ipairs({"Flame", "Earth", "Wind", "Ice", "Metal"}) do
			Guard(function()
				PZ.React(Player, Element, Pos - Inward * 4, Inward)
				T.Eq(PZ.StateOf(Player, ID), "Broken", Element)
			end)
		end
	end,
	-- one real player in Studio: the party is stubbed with a member in the server (Ghost) and one who left (Gone);
	-- SetState is wrapped so the stand-ins are recorded, not driven
	F_BreakIsSharedWithThePartyInTheServer = function(T)
		local RealGet, RealSet = PartyService.Get, PZ.SetState
		local Ghost = {Name = "Ghost", DisplayName = "Ghost", UserId = -9001, Parent = Players}
		local Gone = {Name = "Gone", DisplayName = "Gone", UserId = -9002, Parent = nil}
		local Got = {}
		PartyService.Get = function(P)
			if P == Player then return {Leader = Player, Members = {Player, Ghost, Gone}} end
			return RealGet(P)
		end
		PZ.SetState = function(P, Id, State, For, Permanent)
			if P == Ghost or P == Gone then
				table.insert(Got, {P.Name, Id, State, For, Permanent})
				return true
			end
			return RealSet(P, Id, State, For, Permanent)
		end
		local Ok, Err = pcall(function()
			Guard(function()
				for _ = 1, 3 do PZ.Strike(Player, Pos, false) end
				T.Eq(PZ.StateOf(Player, ID), "Broken", "melee break")
				T.Eq(#Got, 1, "one party member in the server")
				T.Eq(Got[1][1], "Ghost", "the member who is here")
				T.Eq(Got[1][2], ID)
				T.Eq(Got[1][3], "Broken")
				T.Eq(Got[1][4], nil, "not timed")
				T.Eq(Got[1][5], true, "saved for them")
			end)
			table.clear(Got)
			Guard(function()
				PZ.React(Player, "Wind", Pos - Inward * 4, Inward)
				T.Eq(PZ.StateOf(Player, ID), "Broken", "alchemy break")
				T.Eq(#Got, 1, "alchemy shares it too")
				T.Eq(Got[1][1], "Ghost")
				T.Eq(Got[1][5], true)
			end)
			table.clear(Got)
			Guard(function()
				-- the yard vent: a timed, unsaved state (15 s), part of no puzzle
				PZ.React(Player, "Wind", workspace.World.Map.FoundryYard.Interactables.SteamVent.Position, nil)
				T.Eq(#Got, 0, "other mechanisms aren't shared")
			end)
		end)
		PartyService.Get, PZ.SetState = RealGet, RealSet
		if not Ok then error(Err, 0) end
	end,
	-- review fix 1 (2026-10-20): the diagonal loose planks left an R6-sized gap low on the left (z -664..-660).
	-- A Blocker covers the frame's inner opening: off on the server, and PuzzleClient's Draw.Breakable turns it on
	-- while Whole. The client's collision can't be read from here, so Draw.Breakable (PuzzleClient.Draw) runs on an
	-- untagged copy of the model, and an R6 box (4 x 5 x 4) is probed against the copy's COLLIDING parts.
	H_TheBlockerIsOffOnTheServer = function(T)
		local Blocker = Boards:FindFirstChild("Blocker")
		T.True(Blocker ~= nil and Blocker:IsA("BasePart"), "BoardedMouth.Blocker exists")
		T.Eq(Blocker.CanCollide, false, "server: no collision (the client decides)")
		T.Eq(Blocker.Transparency, 1, "invisible")
		T.Eq(Blocker.CanQuery, false, "rays and projectiles pass it")
		T.True(Blocker.Anchored, "anchored")
	end,
	I_WholeClosesTheOpeningAndBrokenClearsIt = function(T)
		local Draw = require(game.ReplicatedStorage.Modules.UI.PuzzleClient:Clone()).Draw
		T.True(type(Draw) == "table" and type(Draw.Breakable) == "function", "PuzzleClient.Draw.Breakable")
		local CS = game:GetService("CollectionService")
		local Copy = Boards:Clone()
		for _, Tag in ipairs(CS:GetTags(Copy)) do CS:RemoveTag(Copy, Tag) end
		for _, D in ipairs(Copy:GetDescendants()) do
			for _, Tag in ipairs(CS:GetTags(D)) do CS:RemoveTag(D, Tag) end
			if D:IsA("ProximityPrompt") then D:Destroy() end
		end
		Copy.Name = "BoardedMouth_TestCopy"
		-- the Blocker is CanQuery off (server rays and projectiles must never stop on it): queryable on the copy only,
		-- so the probe sees it; collision is left to Draw.Breakable
		for _, D in ipairs(Copy:GetDescendants()) do if D:IsA("BasePart") then D.CanQuery = true end end
		Copy.Parent = workspace
		local Op = OverlapParams.new()
		Op.FilterType = Enum.RaycastFilterType.Include
		Op.FilterDescendantsInstances = {Copy}
		local Probe = Instance.new("Part")
		Probe.Anchored = true
		Probe.Size = Vector3.new(4, 5, 4)
		local function Colliding(Z, Y)
			Probe.CFrame = CFrame.new(299.5, Y, Z)
			local N = 0
			for _, Hit in ipairs(workspace:GetPartsInPart(Probe, Op)) do
				if Hit.CanCollide then N += 1 end
			end
			return N
		end
		local Spots = {{-661.5, 11.6}, {-662.5, 11.6}, {-660, 11.6}, {-657, 11.6}, {-663, 12}}
		local Ok, Err = pcall(function()
			Draw.Breakable(Copy, "Whole", false)
			for _, S in ipairs(Spots) do
				T.True(Colliding(S[1], S[2]) > 0, ("Whole: an R6 box at z=%.1f y=%.1f is blocked"):format(S[1], S[2]))
			end
			Draw.Breakable(Copy, "Broken", false)
			for _, S in ipairs(Spots) do
				T.Eq(Colliding(S[1], S[2]), 0, ("Broken: z=%.1f y=%.1f is clear"):format(S[1], S[2]))
			end
			T.Eq(Copy.Blocker.CanCollide, false, "Broken: the Blocker is off")
		end)
		Probe:Destroy()
		Copy:Destroy()
		if not Ok then error(Err, 0) end
	end,
	J_TheInspectTextMatches = function(T)
		local Inv = require(game.ReplicatedStorage.Modules.Data.Rensei.Investigation)
		local Text = Inv.Inspects.adit_mouth.Text
		T.True(not Text:find("slip through", 1, true), "no longer says you can slip through")
		T.True(Text:find("a few good hits", 1, true) ~= nil, "says hitting it works")
	end,
	G_TheBoardsAreAMechanismOnTheModel = function(T)
		local CS = game:GetService("CollectionService")
		T.True(CS:HasTag(Boards, "RenseiMechanism"), "tagged RenseiMechanism")
		T.True(CS:HasTag(Boards, "RenseiInspect"), "still inspectable")
		T.Eq(Boards:GetAttribute("MechanismId"), ID)
		T.Eq(Boards:GetAttribute("InspectId"), "adit_mouth")
	end,
}

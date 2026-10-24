-- TownsfolkLogic (region builds spec §5, Region Foundation plan Task 4): pure rules for townsfolk. No Instances.
-- The roster format lives in Rensei.Townsfolk; a townsperson's Schedule is a list of {From, To, PostId} in
-- world-clock hours (0-24). A slot covers From <= h < To, wrapping past midnight when From > To.
-- The FIRST matching slot wins: PostAt walks the slots in order and returns the first that covers the hour, so in a
-- schedule whose slots overlap, the earlier slot hides the later one for the overlap.
-- Task 6 adds talk: the rotation of what a townsperson says (NextTalk), rumour lines (Rumours / RumourLine) and the
-- ambient chatter lists (Chatter / Chat). Task 6b adds the Hurt / Help lines, the hurt flee's shelter (AwayShelter)
-- and newcomers' names (NewcomerNames / NewcomerName). Every line and number here is a PROPOSAL.
local Factions = require(script.Parent.Factions)
local Customization = require(script.Parent.Customization)

local L = {}

-- Does schedule slot S cover hour H?
local function Covers(S, H)
	local From, To = S[1], S[2]
	if From <= To then return H >= From and H < To end
	return H >= From or H < To
end
L.Covers = Covers

-- The post this schedule puts its townsperson at, at hour Hour (the first matching slot wins). A schedule that
-- leaves a gap (Validate rejects those) falls back to its last slot's post.
function L.PostAt(Schedule, Hour)
	Hour = Hour % 24
	for _, S in ipairs(Schedule) do
		if Covers(S, Hour) then return S[3] end
	end
	local Last = Schedule[#Schedule]
	return Last and Last[3]
end

-- Default greeting per standing tier (Factions.Tiers names). PROPOSAL lines.
L.Greetings = {
	Hostile = "We've nothing to say to you. Move along.",
	Distrusted = "You again. Keep your hands where I can see them.",
	Neutral = "Afternoon. Need something?",
	Trusted = "Good to see you. What can I do for you?",
	Honoured = "Well met! Always a pleasure. Ask away.",
}

-- Def.Greetings (optional) overrides per tier; an unknown tier reads as Neutral.
function L.Greeting(Tier, Def)
	local Own = Def and Def.Greetings
	return (Own and Own[Tier]) or L.Greetings[Tier] or (Own and Own.Neutral) or L.Greetings.Neutral
end

-- Idle animation per post kind (working idles per Documents/Animations.md). Work posts use the
-- townsperson's own Idle, so Work has no entry. PROPOSAL.
L.KindIdles = {Seat = "NPC_Chill", Counter = "NPC_CrossArms", Home = "NPC_Chill", Shelter = "NPC_CurledUp"}

-- Checks one region's roster against the post ids that exist there ({[PostId] = true}).
-- Returns (true, {}) or (false, {error lines}).
function L.Validate(Roster, PostIds)
	local Errs, Seen = {}, {}
	local function Err(Id, Text) table.insert(Errs, tostring(Id) .. ": " .. Text) end
	for I, D in ipairs(Roster) do
		-- a non-table entry is reported, not thrown on (TownsfolkService.LoadRegion runs at Start, unguarded)
		if type(D) ~= "table" then Err("entry " .. I, "is a " .. type(D) .. ", not a townsperson") continue end
		if type(D.Id) ~= "string" then Err(D.Name, "needs a string Id")
		elseif Seen[D.Id] then Err(D.Id, "duplicate id")
		else Seen[D.Id] = true end
		if not Factions.Factions[D.Faction] then Err(D.Id, "unknown faction " .. tostring(D.Faction)) end
		-- dressed from their own nation's pool (owner 2026-10-23): never a random nation
		if type(D.Look) ~= "table" or not Customization.NationLooks[D.Look.Nation] then
			Err(D.Id, "needs Look.Nation, one of Customization.NationLooks (got " .. tostring(type(D.Look) == "table" and D.Look.Nation or nil) .. ")")
		elseif D.Look.Gender ~= nil and not table.find(Customization.Genders, D.Look.Gender) then
			Err(D.Id, "Look.Gender must be one of Customization.Genders (got " .. tostring(D.Look.Gender) .. ")")
		end
		local Schedule = D.Schedule
		local Shaped = type(Schedule) == "table" and #Schedule > 0
		if not Shaped then Err(D.Id, "no schedule") end
		for I, S in ipairs(Shaped and Schedule or {}) do
			if type(S) ~= "table" then S = {} end
			local From, To = S[1], S[2]
			-- (NaN fails every comparison, so it is checked for explicitly: From ~= From)
			if type(From) ~= "number" or type(To) ~= "number" or From ~= From or To ~= To or From < 0 or From > 24 or To < 0 or To > 24 then
				Err(D.Id, "slot " .. I .. " needs hours between 0 and 24")
				Shaped = false
			elseif From == To then
				Err(D.Id, "slot " .. I .. " is empty (from " .. tostring(From) .. " to " .. tostring(To) .. "); use {0, 24, ...} for all day")
			end
			if not PostIds[S[3]] then Err(D.Id, "missing post " .. tostring(S[3])) end
		end
		if Shaped then
			-- Slots are half-open, so any gap starts exactly where some slot ends: checking every slot's
			-- end catches gaps of any length, fractional hours included. Each uncovered hour is reported once.
			local Told = {}
			for _, S in ipairs(Schedule) do
				local Ends = S[2] % 24
				local Covered = false
				for _, Other in ipairs(Schedule) do
					if Covers(Other, Ends) then Covered = true break end
				end
				if not Covered and not Told[Ends] then
					Told[Ends] = true
					Err(D.Id, "nothing scheduled from hour " .. tostring(Ends))
				end
			end
		end
	end
	-- Task 5b: two townsfolk at the same post at the same hour would stand in each other (and the second one to walk
	-- there would wait for a post that never frees up), so a post is one townsperson's at a time. Slots are half-open
	-- ([From, To)), so back to back is fine; a slot past midnight is split in two.
	local Spans = {} -- [PostId] = {{Id, From, To}, ...}
	for _, D in ipairs(Roster) do
		if type(D) ~= "table" or type(D.Schedule) ~= "table" then continue end
		for _, S in ipairs(D.Schedule) do
			if type(S) ~= "table" or type(S[1]) ~= "number" or type(S[2]) ~= "number" or S[1] ~= S[1] or S[2] ~= S[2] or S[3] == nil then continue end
			local function Add(From, To)
				if To <= From then return end
				Spans[S[3]] = Spans[S[3]] or {}
				table.insert(Spans[S[3]], {D.Id, From, To})
			end
			if S[1] <= S[2] then Add(S[1], S[2]) else Add(S[1], 24) Add(0, S[2]) end
		end
	end
	local Told = {}
	for PostId, List in pairs(Spans) do
		for I = 1, #List do
			for J = I + 1, #List do
				local A, B = List[I], List[J]
				local Key = tostring(PostId) .. "|" .. tostring(A[1]) .. "|" .. tostring(B[1])
				if A[1] ~= B[1] and A[2] < B[3] and B[2] < A[3] and not Told[Key] then
					Told[Key] = true
					Err(B[1], "shares post " .. tostring(PostId) .. " with " .. tostring(A[1]) .. " from hour " .. tostring(math.max(A[2], B[2])))
				end
			end
		end
	end
	return #Errs == 0, Errs
end

-- ===== talk (Task 6; owner 2026-10-23: speech bubbles over their heads, no reply choices) =====
-- What a townsperson says when a player talks to them, in this order:
--   1. the clue line, while the player is on Def.Clue.Quest at Def.Clue.Stage (it doesn't move the rotation);
--   2. otherwise the next step of that player's rotation: greeting (by standing tier) -> a rumour the player hasn't
--      heard from this townsperson yet (the step is skipped when there is none) -> the job line -> greeting again.
-- State is the per (player, townsperson) memory {Step, Heard}; the caller keeps it (in memory only).
-- Ctx = {Tier = standing tier name, Rumours = L.Rumours(...) (newest first), Clue = true when the player is on the
-- clue's quest stage}. Returns Kind ("Clue" | "Greeting" | "Rumour" | "Job"), Text.
L.TalkOrder = {"Greeting", "Rumour", "Job"}
function L.NextTalk(Def, State, Ctx)
	Ctx = Ctx or {}
	local Clue = Def and Def.Clue
	if Ctx.Clue and type(Clue) == "table" and type(Clue.Text) == "string" then return "Clue", Clue.Text end
	State.Heard = State.Heard or {}
	for _ = 1, #L.TalkOrder do
		State.Step = (State.Step or 0) % #L.TalkOrder + 1
		local Kind = L.TalkOrder[State.Step]
		if Kind == "Greeting" then
			return Kind, L.Greeting(Ctx.Tier, Def)
		elseif Kind == "Rumour" then
			for _, R in ipairs(Ctx.Rumours or {}) do
				if not State.Heard[R.Key] then
					State.Heard[R.Key] = true
					return Kind, R.Text
				end
			end
		elseif Kind == "Job" and type(Def.JobLine) == "string" and Def.JobLine ~= "" then
			return Kind, Def.JobLine
		end
	end
	return "Greeting", L.Greeting(Ctx.Tier, Def) -- (unreachable: the greeting step always speaks)
end

-- A deed's Text is a capitalised reason line ("Struck a townsperson"); a rumour says it about someone:
-- "They say <subject> struck a townsperson." When the listener is the subject: "They say you struck a townsperson."
-- (PROPOSAL wording). A third-person line swaps the reason line's "you'd" / "your" (written to the player) for
-- "they'd" / "their".
local function LowerFirst(Text) return Text:sub(1, 1):lower() .. Text:sub(2) end
function L.RumourLine(Subject, Text, IsListener)
	local Body = LowerFirst((tostring(Text):gsub("[%.%s]+$", "")))
	if IsListener then return "They say you " .. Body .. "." end
	Body = Body:gsub("%f[%a]you'd%f[%A]", "they'd"):gsub("%f[%a]your%f[%A]", "their")
	return "They say " .. tostring(Subject) .. " " .. Body .. "."
end

-- RumourService.HeardIn entries ({At, Text, Subject}, newest first) -> the lines a townsperson can pass on to
-- Listener: {{Key, Text}, ...}, one per (Subject, Text) (the same deed lands once per faction, so it can repeat).
-- NameOf(Subject) -> how the listener knows the subject ("someone" when they don't).
function L.Rumours(Heard, Listener, NameOf)
	local Out, Seen = {}, {}
	for _, H in ipairs(Heard or {}) do
		local Subject = H.Subject
		local Who = typeof(Subject) == "Instance" and Subject:IsA("Player") and Subject.UserId or tostring(Subject)
		local Key = tostring(Who) .. "|" .. tostring(H.Text)
		if H.Text and not Seen[Key] then
			Seen[Key] = true
			local Mine = Subject ~= nil and Subject == Listener
			local Name = (not Mine and NameOf and NameOf(Subject)) or "someone"
			table.insert(Out, {Key = Key, Text = L.RumourLine(Name, H.Text, Mine)})
		end
	end
	return Out
end

-- How long a line stays over their head (seconds). PROPOSAL.
function L.SpeechSeconds(Text) return 3 + 0.05 * #tostring(Text or "") end

-- Ambient chatter (PROPOSAL lines): Pass (a player first comes near), Shift (the schedule moves them on), Flee (a
-- fight nearby: running for shelter), Return (calm again, back to the day), Hurt and Help (Task 6b, below).
L.Chatter = {
	Pass = {"Mind how you go.", "Keep well.", "Don't see many new faces round here.", "Busy day, this.", "Watch your pockets in a crowd."},
	Shift = {"Right, that's me done here.", "Time I moved on.", "Off I go, then.", "Where does the day go?"},
	Flee = {"Fighting! Get inside!", "Not again - run!", "Someone fetch the Authority!", "Get away from here!"},
	Return = {"Is it over?", "Seems quiet now.", "Back to it, I suppose.", "That was too close."},
	-- Task 6b: Hurt (the townsperson a player hit, or one getting up after being knocked down), Help (others near it)
	Hurt = {"Agh! Stop!", "What are you doing?!", "Leave me be!", "Please, no more!"},
	Help = {"Help! Someone help!", "They're killing someone!", "Fetch the watch!", "Somebody stop them!"},
}

-- Task 6b: where a hurt townsperson runs. Shelters = {{Id = PostId, Pos = Vector3}, ...}; of the N (default 3)
-- nearest At, the one farthest from From (the attacker). Ties go to the lower Id. nil when there are none.
-- MaxDist (optional; Lindenmoor import Task 8 fix round 3): only shelters within this many studs of At count (nil when
-- none is: the caller curls up where it stands).
function L.AwayShelter(Shelters, At, From, N, MaxDist)
	local List = {}
	for _, S in ipairs(Shelters or {}) do
		if not MaxDist or (S.Pos - At).Magnitude <= MaxDist then table.insert(List, S) end
	end
	table.sort(List, function(A, B)
		local DA, DB = (A.Pos - At).Magnitude, (B.Pos - At).Magnitude
		if DA ~= DB then return DA < DB end
		return tostring(A.Id) < tostring(B.Id)
	end)
	local Best, BestD
	for I = 1, math.min(N or 3, #List) do
		local D = (List[I].Pos - From).Magnitude
		if not Best or D > BestD then Best, BestD = List[I].Id, D end
	end
	return Best
end

-- Task 6b: when a townsperson is killed, a newcomer takes the job at the next 06:00 (same Id, job, faction, nation and
-- schedule; a new name and look). PROPOSAL names, 8 per nation (Customization.NationLooks).
L.NewcomerNames = {
	Amestrian = {"Hal Brenner", "Greta Vossler", "Emil Hartwig", "Ruth Calder", "Otto Fenwick", "Clara Holm", "Pieter Lang", "Mina Albrecht"},
	Xingnese = {"Lin Shao", "Mei Tan", "Wen Hu", "Jia Rong", "Bo Lan", "Xiu Fen", "Kai Zhou", "Ren Yue"},
	Ishvalan = {"Adin", "Sarai", "Tamir", "Leah", "Ezra", "Nadia", "Yosef", "Hanna"},
	Xerxian = {"Daris", "Mithra", "Cyra", "Arsen", "Roshan", "Tahmin", "Parisa", "Kaveh"},
	Aerugonian = {"Marco Vela", "Lucia Ferro", "Teo Bassi", "Giulia Rinaldi", "Nico Sarti", "Elena Costa", "Paolo Greco", "Sofia Lenti"},
	Drachman = {"Pyotr Volkov", "Anya Orlova", "Ivan Sokol", "Vera Petrova", "Lev Morozov", "Yelena Kuzna", "Boris Rybak", "Mila Zorin"},
}

-- a newcomer's name: one of NewcomerNames[Nation] that isn't in Taken ([Name] = true: the names alive in the region,
-- and the dead one's), picked with Rng. nil when every name is taken.
function L.NewcomerName(Nation, Taken, Rng)
	local Free = {}
	for _, Name in ipairs(L.NewcomerNames[Nation] or {}) do
		if not (Taken and Taken[Name]) then table.insert(Free, Name) end
	end
	if #Free == 0 then return nil end
	return Free[Rng and Rng:NextInteger(1, #Free) or math.random(#Free)]
end
function L.Chat(Kind, Rng)
	local List = L.Chatter[Kind]
	if not List or #List == 0 then return nil end
	return List[Rng and Rng:NextInteger(1, #List) or math.random(#List)]
end

return L

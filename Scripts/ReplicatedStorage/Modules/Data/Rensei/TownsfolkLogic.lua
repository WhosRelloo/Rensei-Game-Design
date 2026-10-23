-- TownsfolkLogic (region builds spec §5, Region Foundation plan Task 4): pure rules for townsfolk. No Instances.
-- The roster format lives in Rensei.Townsfolk; a townsperson's Schedule is a list of {From, To, PostId} in
-- world-clock hours (0-24). A slot covers From <= h < To, wrapping past midnight when From > To.
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

-- The post this schedule puts its townsperson at, at hour Hour. A schedule that leaves a gap (Validate
-- rejects those) falls back to its last slot's post.
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
			if type(S[1]) ~= "number" or type(S[2]) ~= "number" or S[1] < 0 or S[1] > 24 or S[2] < 0 or S[2] > 24 then
				Err(D.Id, "slot " .. I .. " needs hours between 0 and 24")
				Shaped = false
			end
			if not PostIds[S[3]] then Err(D.Id, "missing post " .. tostring(S[3])) end
		end
		if Shaped then
			-- Slots are half-open, so any gap starts exactly where some slot ends: checking every slot's
			-- end catches gaps of any length, fractional hours included.
			for _, S in ipairs(Schedule) do
				local Ends = S[2] % 24
				local Covered = false
				for _, Other in ipairs(Schedule) do
					if Covers(Other, Ends) then Covered = true break end
				end
				if not Covered then Err(D.Id, "nothing scheduled from hour " .. tostring(Ends)) end
			end
		end
	end
	return #Errs == 0, Errs
end

return L

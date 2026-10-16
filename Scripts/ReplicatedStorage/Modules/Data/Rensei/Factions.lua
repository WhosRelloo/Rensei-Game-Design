-- Morality tracks (Morality and Reputation Proposal.md, owner approved the defaults 2026-10-16).
-- Shared by MoralityService (server), StoryLogic conditions and the UI. Pure data + helpers.
-- Players only ever see WORDS (tiers, conduct words, renown ranks), never the numbers.
-- PLACEHOLDER factions (owner-approved as placeholders): only the State Authority existed before.
-- Every number is a PROPOSAL.

local Factions = {}

Factions.Factions = {
	Authority = {Name = "State Authority"},
	Foundry = {Name = "Foundry Hands"}, -- the yard's workers and smelters
	Circle = {Name = "Unlicensed Circle"}, -- alchemists working without a licence
	Townsfolk = {Name = "Townsfolk"}, -- ordinary people of the district
}
Factions.Order = {"Authority", "Foundry", "Circle", "Townsfolk"}

-- Standing tiers, worst to best. A value is in the last tier whose Min it reaches.
Factions.Tiers = {
	{Name = "Hostile", Min = -math.huge, Max = -60},
	{Name = "Distrusted", Min = -59, Max = -20},
	{Name = "Neutral", Min = -19, Max = 19},
	{Name = "Trusted", Min = 20, Max = 59},
	{Name = "Honoured", Min = 60, Max = math.huge},
}

-- Conduct axes (who you are). Shown as a word once a lean is clear.
Factions.Axes = {
	Mercy = {Low = "Ruthless", High = "Merciful"},
	Candor = {Low = "Deceitful", High = "Honest"},
	Order = {Low = "Defiant", High = "Lawful"},
}
Factions.AxisOrder = {"Mercy", "Candor", "Order"}
Factions.Lean = 15 -- |value| at which the word shows

-- Renown ranks (how widely you are known). Never goes down.
Factions.Ranks = {
	{Name = "Unknown", Min = 0},
	{Name = "Noticed", Min = 50},
	{Name = "Known", Min = 200},
	{Name = "Renowned", Min = 600},
	{Name = "Famed", Min = 1500},
}

Factions.Limit = 100 -- conduct, standing and trust read as -100..100 (the ledger keeps raw sums)

function Factions.Clamp(V)
	return math.clamp(math.floor((V or 0) + 0.5), -Factions.Limit, Factions.Limit)
end

function Factions.TierOf(Value)
	local V = Factions.Clamp(Value)
	local Best = Factions.Tiers[1]
	for _, T in ipairs(Factions.Tiers) do if V >= T.Min then Best = T end end
	return Best.Name
end

function Factions.Tier(Name)
	for I, T in ipairs(Factions.Tiers) do if T.Name == Name then return T, I end end
end

-- "Merciful" / "Ruthless" / nil (no clear lean yet)
function Factions.Word(Axis, Value)
	local A = Factions.Axes[Axis]
	local V = Factions.Clamp(Value)
	if not A or math.abs(V) < Factions.Lean then return nil end
	return V > 0 and A.High or A.Low
end

function Factions.RankOf(Renown)
	local Best = Factions.Ranks[1]
	for _, R in ipairs(Factions.Ranks) do if (Renown or 0) >= R.Min then Best = R end end
	return Best.Name
end

-- A condition threshold: a number, or a tier name ("Trusted" = its Min, for at-least checks;
-- AtMost = true gives the tier's Max, for at-most checks).
function Factions.Threshold(V, AtMost)
	if type(V) == "number" then return V end
	local T = Factions.Tier(V)
	if T then return AtMost and T.Max or T.Min end
	return AtMost and -math.huge or math.huge -- unknown name: never passes
end

return Factions

-- Alchemist ranks (owner's leaderboard prompt, 2026-10-17). Shared: the server works out each
-- player's rank (RankService); clients only read the names and lines here to draw the leaderboard.
-- A rank above 1 is EARNED. The level only makes a player eligible; the promotion itself is a Story
-- flag that only the server sets (a quest reward, a dialogue action, or the admin panel's SetRank),
-- and it counts only while the level requirement is also met. Rank 4 is WIP: nothing grants it.
-- PROPOSAL: the flag names and the "Needs" wording; no quest grants the License or the Master
-- promotion yet, so in normal play everyone is an Apprentice until that content exists.

local Ranks = {}

Ranks.List = {
	{Rank = 1, Title = "Apprentice", MinLevel = 1, MaxLevel = 5,
		Description = "Learns basic transmutations and combat.",
		Unlocks = "Custom Transmutation Circles"},
	{Rank = 2, Title = "State Alchemist", MinLevel = 6, MaxLevel = 10, Flag = "StateLicense", Needs = "the State Alchemist License",
		Description = "Gains access to advanced alchemy circles and elemental styles.",
		Unlocks = "State Alchemist License, restricted laboratories, special quests"},
	{Rank = 3, Title = "Master Alchemist", MinLevel = 11, MaxLevel = 15, Flag = "Promotion_Master", Needs = "a Master promotion",
		Description = "Can craft custom transmutations and complex constructs.",
		Unlocks = "Elemental Affinity Choice, advanced transmutations, complex constructs"},
	{Rank = 4, Title = "Philosopher's Tier", MinLevel = 16, MaxLevel = 20, WIP = true,
		Description = "An elite tier for alchemists who have mastered advanced transmutation.",
		Unlocks = "Work in progress"},
}

-- Rank from trusted data (the server's copy of the save): Level, Flags -> rank number, status line.
-- Each rank needs every rank below it, its own flag, and its level.
function Ranks.Evaluate(Level, Flags)
	Level = tonumber(Level) or 1
	Flags = type(Flags) == "table" and Flags or {}
	local Rank = 1
	for I = 2, #Ranks.List do
		local R = Ranks.List[I]
		if R.WIP or not R.Flag or Flags[R.Flag] == nil or Level < R.MinLevel then break end
		Rank = I
	end
	local Next = Ranks.List[Rank + 1]
	local Status
	if not Next then
		Status = "Highest rank"
	elseif Level < Next.MinLevel then
		Status = ("Next rank: %s at level %d"):format(Next.Title, Next.MinLevel)
	elseif Next.WIP then
		Status = Next.Title .. " is not open yet (work in progress)"
	else
		Status = ("Eligible for %s: needs %s"):format(Next.Title, Next.Needs)
	end
	return Rank, Status
end

return Ranks

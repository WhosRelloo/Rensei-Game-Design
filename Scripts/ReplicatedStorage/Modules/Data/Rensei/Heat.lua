-- Heat (2026-10-20, Morality × Reputation spec §6; Plan 2, slice R3): the numbers and the pure maths of Heat
-- and Wanted. HeatService (server) is the only writer of the save's Morality.Heat; StoryLogic and the HUD read
-- it through these functions, so both sides agree. Every number is a PROPOSAL (spec §18.4).
--   Morality.Heat[Jurisdiction] = {Value = n, At = os.time(), Window = {[Region] = {Hour = n, Gained = n}}}
--   Value is the Heat at time At; it decays from there (DecayPerHour, real time, offline included).
-- Jurisdictions: State (the Authority's law, State places), Militia (Townsfolk law, Militia places), Circle
-- (deeds against the Circle, wherever the Circle hears them).

local Heat = {}

Heat.Order = {"State", "Militia", "Circle"}
Heat.Thresholds = {20, 50, 100, 180, 300} -- Wanted 1..5
Heat.DecayPerHour = 5 -- with no new crime
Heat.FinePerLevel = 100 -- the fine at a State desk: 100 x level
Heat.FineMaxWanted = 2 -- fines are only taken up to Wanted 2

-- the faction whose hearing of a crime raises each jurisdiction's Heat (Rensei.Factions ids)
Heat.Law = {State = "Authority", Militia = "Townsfolk", Circle = "Circle"}

-- the HUD: name and colour per jurisdiction (PROPOSAL)
Heat.Names = {State = "State", Militia = "Militia", Circle = "Circle"}
Heat.Colors = {
	State = Color3.fromRGB(96, 140, 210),
	Militia = Color3.fromRGB(176, 128, 82),
	Circle = Color3.fromRGB(170, 52, 60),
}

function Heat.Wanted(Value)
	local W = 0
	for I, T in ipairs(Heat.Thresholds) do
		if (Value or 0) >= T then W = I end
	end
	return W
end

-- the Heat now, after decay
function Heat.Current(Entry, Now)
	if type(Entry) ~= "table" then return 0 end
	local V = tonumber(Entry.Value) or 0
	local At = tonumber(Entry.At) or Now
	return math.max(0, V - Heat.DecayPerHour * math.max(0, Now - At) / 3600)
end

-- Heat table (Morality.Heat) helpers: Value / Wanted now, for one jurisdiction
function Heat.ValueOf(H, J, Now) return Heat.Current(H and H[J], Now) end
function Heat.WantedOf(H, J, Now) return Heat.Wanted(Heat.ValueOf(H, J, Now)) end

-- adds Amount (decay applied first). Cap (optional) = the most this kind of crime may add in Region per hour.
-- Returns the amount actually added.
function Heat.Add(H, J, Amount, Now, Region, Cap)
	local E = H[J] or {Value = 0, At = Now}
	H[J] = E
	if Cap and Region then
		E.Window = E.Window or {}
		local Hour = math.floor(Now / 3600)
		local W = E.Window[Region]
		if not W or W.Hour ~= Hour then W = {Hour = Hour, Gained = 0}; E.Window[Region] = W end
		Amount = math.max(0, math.min(Amount, Cap - W.Gained))
		W.Gained += Amount
	end
	if Amount <= 0 then return 0 end
	E.Value = Heat.Current(E, Now) + Amount
	E.At = Now
	return Amount
end

function Heat.Clear(H, J, Now)
	local E = H[J]
	if not E then return end
	E.Value, E.At = 0, Now
end

-- which jurisdictions a crime raises when it is heard in Region by the factions in Heard:
-- State / Militia when that law's faction hears it in a place under that law; Circle when the Circle hears a
-- deed against it (CircleHeat), anywhere.
function Heat.Raised(RegionDef, Heard, Def)
	local Out = {}
	if not RegionDef or type(Def) ~= "table" then return Out end
	local function Hears(F) return table.find(Heard, F) ~= nil end
	local J = RegionDef.Jurisdiction
	if (Def.Crime or 0) > 0 and Heat.Law[J] and J ~= "Circle" and Hears(Heat.Law[J]) then
		table.insert(Out, {J = J, Amount = Def.Crime})
	end
	if (Def.CircleHeat or 0) > 0 and Hears(Heat.Law.Circle) then
		table.insert(Out, {J = "Circle", Amount = Def.CircleHeat})
	end
	return Out
end

return Heat

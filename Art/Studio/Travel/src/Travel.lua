-- Travel (2026-10-20, world spec §2–4): the pure rules of getting between regions. Routes join two regions
-- (Rail = the train, Road = a road journey); a ticket is for one route and one class. Every number is a PROPOSAL.
local Travel = {}

Travel.Classes = {
	Third = {Name = "3rd class", Mult = 1, Cars = {ThirdClass = true, DiningCar = true}},
	Second = {Name = "2nd class", Mult = 2, Cars = {ThirdClass = true, DiningCar = true, SecondClass = true}},
	Cabin = {Name = "Private cabin", Mult = 5, Cars = {ThirdClass = true, DiningCar = true, SecondClass = true, CabinCar = true}},
}
Travel.ClassOrder = {"Third", "Second", "Cabin"}

-- Rail: Base = 3rd-class price, Every = seconds between departures, Ride = seconds aboard, Level = minimum level
-- Road: Seconds = the journey
Travel.Routes = {
	LindenmoorFoundry = {Kind = "Rail", A = "Lindenmoor", B = "Foundry", Base = 15, Every = 150, Ride = 50},
	FoundryCity = {Kind = "Rail", A = "Foundry", B = "City", Base = 15, Every = 150, Ride = 50, Level = 8},
	CityIshval = {Kind = "Rail", A = "City", B = "Ishval", Base = 40, Every = 180, Ride = 60, Level = 18},
	RoadLindenmoorFoundry = {Kind = "Road", A = "Lindenmoor", B = "Foundry", Seconds = 40},
	RoadFoundryCity = {Kind = "Road", A = "Foundry", B = "City", Seconds = 35, Level = 8},
	RoadCityAerugo = {Kind = "Road", A = "City", B = "Aerugo", Seconds = 50, Level = 12},
	RoadCityIshval = {Kind = "Road", A = "City", B = "Ishval", Seconds = 60, Level = 18},
	RoadCityNorth = {Kind = "Road", A = "City", B = "North", Seconds = 45, Level = 25},
	RoadNorthCorrupted = {Kind = "Road", A = "North", B = "Corrupted", Seconds = 40, Level = 30},
	RoadAerugoCorrupted = {Kind = "Road", A = "Aerugo", B = "Corrupted", Seconds = 45, Level = 30},
}

Travel.BoardingWindow = 30 -- seconds before departure that the doors open
Travel.WinterMult = 1.2
Travel.FineMult = 3
Travel.BribeMult = 2

Travel.RideEvents = { -- weights add up to 100
	{Id = "Inspection", Weight = 40},
	{Id = "Rumour", Weight = 30},
	{Id = "Pickpocket", Weight = 15},
	{Id = "Quiet", Weight = 10},
	{Id = "Holdup", Weight = 5},
}

function Travel.Other(RouteId, From)
	local R = Travel.Routes[RouteId]
	if not R then return nil end
	if R.A == From then return R.B end
	if R.B == From then return R.A end
	return nil
end

function Travel.RoutesFrom(Region, Kind)
	local Out = {}
	for Id, R in pairs(Travel.Routes) do
		if (R.A == Region or R.B == Region) and (not Kind or R.Kind == Kind) then table.insert(Out, Id) end
	end
	table.sort(Out)
	return Out
end

function Travel.Price(RouteId, ClassId, Season)
	local R, C = Travel.Routes[RouteId], Travel.Classes[ClassId]
	if not R or not C or R.Kind ~= "Rail" then return 0 end
	local P = R.Base * C.Mult * (Season == "Winter" and Travel.WinterMult or 1)
	return math.floor(P + 0.5)
end

function Travel.Fine(RouteId)
	local R = Travel.Routes[RouteId]
	return R and R.Base and R.Base * Travel.FineMult or 0
end

function Travel.Bribe(RouteId, ClassId, Season)
	return Travel.Price(RouteId, ClassId, Season) * Travel.BribeMult
end

function Travel.NextDeparture(RouteId, Now)
	local R = Travel.Routes[RouteId]
	if not R or not R.Every then return nil end
	return (math.floor(Now / R.Every) + 1) * R.Every
end

function Travel.BoardingOpen(RouteId, Now)
	local D = Travel.NextDeparture(RouteId, Now)
	return D ~= nil and D - Now <= Travel.BoardingWindow
end

function Travel.Gate(Wanted)
	if Wanted <= 0 then return "Pass" end
	if Wanted <= 2 then return "Bribe" end
	return "Refuse"
end

function Travel.AmbushChance(Night, Winter, Wanted)
	local C = 0.15 + (Night and 0.05 or 0) + (Winter and 0.05 or 0) + 0.10 * (Wanted or 0)
	return math.min(C, 0.6)
end

-- Roll in [0, 1)
function Travel.PickRideEvent(Roll)
	local Acc = 0
	for _, E in ipairs(Travel.RideEvents) do
		Acc += E.Weight / 100
		if Roll < Acc - 1e-9 then return E.Id end
	end
	return Travel.RideEvents[#Travel.RideEvents].Id
end

function Travel.CanTake(Level, RouteId)
	local R = Travel.Routes[RouteId]
	if not R then return false, "No such route." end
	if R.Level and (Level or 0) < R.Level then return false, ("You need to be level %d."):format(R.Level) end
	return true
end

function Travel.ClassReaches(ClassId, CarKind)
	local C = Travel.Classes[ClassId]
	return C ~= nil and C.Cars[CarKind] == true
end

function Travel.TicketKey(RouteId, ClassId)
	return RouteId .. "|" .. ClassId
end

return Travel

-- Plan 2 (R3): the pure Heat maths (Rensei.Heat) and the StoryLogic Heat / Wanted conditions.
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Heat = require(Rensei.Heat)
local StoryLogic = require(Rensei.StoryLogic)
local Regions = require(Rensei.Regions)
return {
	Thresholds = function(T)
		T.Eq(Heat.Wanted(0), 0)
		T.Eq(Heat.Wanted(19.9), 0)
		T.Eq(Heat.Wanted(20), 1)
		T.Eq(Heat.Wanted(50), 2)
		T.Eq(Heat.Wanted(99), 2)
		T.Eq(Heat.Wanted(100), 3)
		T.Eq(Heat.Wanted(180), 4)
		T.Eq(Heat.Wanted(300), 5)
		T.Eq(Heat.Wanted(9999), 5)
	end,
	DecaysFiveAnHour = function(T)
		local H = {}
		Heat.Add(H, "State", 30, 1000)
		T.Near(Heat.ValueOf(H, "State", 1000), 30)
		T.Near(Heat.ValueOf(H, "State", 1000 + 3600), 25, 1e-6, "one hour")
		T.Near(Heat.ValueOf(H, "State", 1000 + 3600 * 10), 0, 1e-6, "never below 0")
		Heat.Add(H, "State", 10, 1000 + 3600) -- decay applied first: 25 + 10
		T.Near(Heat.ValueOf(H, "State", 1000 + 3600), 35)
	end,
	CapPerPlacePerHour = function(T)
		local H = {}
		local Now = 3600 * 100
		T.Eq(Heat.Add(H, "State", 10, Now, "Foundry", 30), 10)
		T.Eq(Heat.Add(H, "State", 10, Now + 1, "Foundry", 30), 10)
		T.Eq(Heat.Add(H, "State", 10, Now + 2, "Foundry", 30), 10)
		T.Eq(Heat.Add(H, "State", 10, Now + 3, "Foundry", 30), 0, "capped at 30 in the Foundry this hour")
		T.Eq(Heat.Add(H, "State", 10, Now + 4, "City", 30), 10, "another place has its own cap")
		T.Eq(Heat.Add(H, "State", 10, Now + 3600, "Foundry", 30), 10, "a new hour")
	end,
	Clear = function(T)
		local H = {}
		Heat.Add(H, "Militia", 60, 5)
		Heat.Clear(H, "Militia", 6)
		T.Eq(Heat.ValueOf(H, "Militia", 6), 0)
		T.Eq(Heat.ValueOf(nil, "Militia", 6), 0, "no table yet")
	end,
	-- whose Heat a crime raises where it's heard
	RaisedByTheLawThatHears = function(T)
		local Crime = {Crime = 15}
		local function Js(Region, Heard, Def)
			local Out = {}
			for _, X in ipairs(Heat.Raised(Regions.Regions[Region], Heard, Def)) do table.insert(Out, X.J .. "=" .. X.Amount) end
			return table.concat(Out, ",")
		end
		T.Eq(Js("City", {"Authority", "Townsfolk"}, Crime), "State=15", "the Authority hears it in the City")
		T.Eq(Js("Foundry", {"Foundry", "Townsfolk"}, Crime), "", "no Authority in the Foundry: no State Heat yet")
		T.Eq(Js("Foundry", {"Authority"}, Crime), "State=15", "an Authority agent in the Foundry")
		T.Eq(Js("Lindenmoor", {"Townsfolk", "Circle"}, Crime), "Militia=15", "Townsfolk law in Lindenmoor")
		T.Eq(Js("City", {"Townsfolk"}, Crime), "", "Townsfolk in a State place aren't the law")
		T.Eq(Js("Adit", {"Townsfolk"}, Crime), "", "no law at the Adit")
		T.Eq(Js("City", {"Circle"}, {CircleHeat = 15}), "Circle=15", "the Circle hears a deed against it")
		T.Eq(Js("City", {"Authority"}, {Standing = {Authority = 5}}), "", "not a crime")
	end,
	Conditions = function(T)
		local Now = os.time()
		local Data = {Morality = {Heat = {State = {Value = 60, At = Now}}}}
		T.True(StoryLogic.Meets({Heat = {State = 1}}, Data), "has State Heat")
		T.True(StoryLogic.Meets({Wanted = {State = 2}}, Data), "Wanted 2")
		T.True(not StoryLogic.Meets({Wanted = {State = 3}}, Data), "not Wanted 3")
		T.True(StoryLogic.Meets({WantedBelow = {State = 2}}, Data), "at most 2")
		T.True(not StoryLogic.Meets({WantedBelow = {State = 1}}, Data), "more than 1")
		T.True(not StoryLogic.Meets({Heat = {Militia = 1}}, Data), "no Militia Heat")
		T.True(StoryLogic.Meets({HeatBelow = {Militia = 1}}, Data), "Militia clean")
		T.True(StoryLogic.Meets({HeatBelow = {State = 1}}, {Morality = {}}), "an old save with no Heat")
	end,
}

-- server modules live in ServerStorage.RenseiServer in Edit mode (World Plan 1 Task 3); ServerScriptService at runtime
local Migrations = require(game.ServerScriptService:FindFirstChild("ProfileMigrations") or game.ServerStorage.RenseiServer.ProfileMigrations)
return {
	FourToFive = function(T)
		local Data = {SchemaVersion = 4, Morality = {Deeds = {reported_lise = {At = 1, Count = 1, Seen = 1}}, Standing = {}, Renown = 0}}
		Migrations.Migrate(Data)
		T.Eq(Data.SchemaVersion, 5)
		for _, K in ipairs({"Places", "Rumours", "Heat", "News"}) do T.Eq(type(Data.Morality[K]), "table", K) end
		T.Same(Data.Licence, {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0})
		T.Eq(Data.Morality.Deeds.reported_lise.Count, 1, "the ledger is untouched")
	end,
	FullChainFromNothing = function(T)
		local Data = {Level = 3}
		Migrations.Migrate(Data)
		T.Eq(Data.SchemaVersion, 5)
		T.Eq(type(Data.Morality.Places), "table")
	end,
	KeepsExistingLicence = function(T)
		local Data = {SchemaVersion = 4, Licence = {Path = "State", Since = 9, Orders = {}, Refused = {}, Revoked = 0}}
		Migrations.Migrate(Data)
		T.Eq(Data.Licence.Path, "State")
	end,
	-- Plan 1 follow-up (2026-10-20): Places / Heat a save already has survive the 4 -> 5 step
	ExistingPlacesAndHeatSurvive = function(T)
		local Data = {SchemaVersion = 4, Morality = {Deeds = {}, Places = {City = {Known = {x = {Authority = 5}}}},
			Heat = {State = {Value = 42, At = 7}}}}
		Migrations.Migrate(Data)
		T.Eq(Data.Morality.Places.City.Known.x.Authority, 5, "places kept")
		T.Eq(Data.Morality.Heat.State.Value, 42, "heat kept")
	end,
	Schema5IsANoOp = function(T)
		local Data = {SchemaVersion = 5, Level = 4, Morality = {Deeds = {}, Places = {}, Rumours = {{Id = "r"}}, Heat = {State = {Value = 1, At = 2}}, News = {}},
			Licence = {Path = "Circle", Since = 3, Orders = {}, Refused = {}, Revoked = 0}}
		local Before = game:GetService("HttpService"):JSONEncode(Data)
		Migrations.Migrate(Data)
		T.Eq(game:GetService("HttpService"):JSONEncode(Data), Before, "a schema-5 save is left exactly as it was")
	end,
	TemplateIsSchema5 = function(T)
		local Template = require(game.ReplicatedStorage.Modules.Data.ProfileData)
		T.Eq(Template.SchemaVersion, 5)
		T.Eq(type(Template.Morality.Places), "table")
		T.Eq(Template.Licence.Path, "")
	end,
}

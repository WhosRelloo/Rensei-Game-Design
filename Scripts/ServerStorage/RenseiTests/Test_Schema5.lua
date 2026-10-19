local Migrations = require(game.ServerScriptService.ProfileMigrations)
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
	TemplateIsSchema5 = function(T)
		local Template = require(game.ReplicatedStorage.Modules.Data.ProfileData)
		T.Eq(Template.SchemaVersion, 5)
		T.Eq(type(Template.Morality.Places), "table")
		T.Eq(Template.Licence.Path, "")
	end,
}
